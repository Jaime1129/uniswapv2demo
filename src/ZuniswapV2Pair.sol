// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./util/Math.sol";
import "solmate/tokens/ERC20.sol";
import "./util/UQ112x112.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InsufficientLiquidity();
error InvalidK();
error BalanceOverflow();

contract ZUniSwapV2Pair is ERC20, Math {
    using UQ112x112 for uint224;

    uint256 constant MINIMUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;

    // pool reserve of tokens for avoiding price manipulation
    uint112 private reserve0;
    uint112 private reserve1;

    // timestamp of last swapping
    uint32 private blockTimestampLast;
    // delta price * time elapsed since last swapping
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    constructor(address _token0, address _token1) ERC20("ZUniSwapV2Pair", "ZUNIV2", 18) {
        token0 = _token0;
        token1 = _token1;
    }

    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(address indexed sender, uint256 amount0, uint256 amount1, address to);

    // mint LP tokens when adding liquidity
    function mint() public {
        // query current contract balance of both tokens
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // amount are newly depoited tokens that haven't been counted into reserves
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 liquidity;

        // calculate the LP tokens that must be issued to LP
        if (totalSupply == 0) {
            // if no LP tokens so far, mint the geo mean of deposited amounts
            liquidity = sqrt(amount0*amount1) - MINIMUM_LIQUIDITY;
            // remove some initial liquidity to prevent someone from making LP token too expensive
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = min(
                (amount0*totalSupply)/reserve0,
                (amount1*totalSupply)/reserve1
            );
        }

        if (liquidity <= 0) {
            // the initally provided tokens amount cannot be too small
            revert InsufficientLiquidityMinted();
        } 

        // distribute LP tokens to LP
        _mint(msg.sender, liquidity);
        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn() public {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        // bug: burn user token without permission 
        uint256 liquidity = balanceOf[msg.sender];
        
        uint256 amount0 = liquidity * balance0 / totalSupply;
        uint256 amount1 = liquidity * balance1 / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) {
            revert InsufficientLiquidityBurned();
        }

        // burn LP tokens
        _burn(msg.sender, liquidity);
        
        // transfer tokens back to user
        _safeTranser(token0, msg.sender, amount0);
        _safeTranser(token1, msg.sender, amount1);

        // update reserve
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        (uint112 reserve0_, uint112 reserve1_) = getReserves();
        _update(balance0, balance1, reserve0_, reserve1_);

        emit Burn(msg.sender, amount0, amount1);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) public {
        if (amount0Out <= 0 || amount1Out <= 0) {
            revert InsufficientOutputAmount();
        }
        (uint112 reserve0_, uint112 reserve1_) = getReserves();
        if (amount0Out > reserve0_ || amount1Out > reserve1_) {
            revert InsufficientLiquidity();
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) - amount0Out;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amount1Out;

        // the new constant K must equal or larger than current one
        if (balance0 * balance1 < uint256(reserve0_) * uint256(reserve1_)) {
            revert InvalidK();
        }

        _update(balance0, balance1, reserve0_, reserve1_);

        if (amount0Out > 0) _safeTranser(token0, to, amount0Out);
        if (amount1Out > 0) _safeTranser(token1, to, amount1Out);

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    //
    // PRIVATE
    // 

    // update reserve amount
    function _update(
        uint256 balance0, 
        uint256 balance1,
        uint112 reserve0_,
        uint112 reserve1_
    ) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert BalanceOverflow();
        }

        // The unchecked block in Solidity allows developers to bypass these automatic overflow and underflow checks within the scope of the block. 
        // This can be useful for optimizing gas costs in situations where the developer is certain that overflows or underflows cannot occur, 
        // or when such conditions are intended or managed manually.
        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;
            if (timeElapsed > 0 && reserve0_ > 0 && reserve1_ > 0) {
                price0CumulativeLast = uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed;
                price1CumulativeLast = uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
            }
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);

        emit Sync(reserve0, reserve1);
    }

    // transfer tokens 
    function _safeTranser(address token, address receiver, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", receiver, amount));
        if(!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

}

