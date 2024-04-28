// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ZuniswapV2Factory.sol";
import "./ZuniswapV2Pair.sol";
import "./ZuniswapV2Library.sol";

error InsufficientAAmount();
error InsufficientBAmount();
error SafeTransferFailed();

contract ZUniSwapV2Router {
    ZUniSwapV2Factory factory;

    constructor(address _factory) {
        factory = ZUniSwapV2Factory(_factory);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // if pair contract doesn't exist, create it
        if (factory.pairs(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        address pairAddress = ZUniSwapV2Library.pairFor(
            address(factory),
            tokenA,
            tokenB
        );
        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);

        liquidity = ZUniSwapV2Pair(pairAddress).mint(to);
    }

    function removeLiquidity(
                address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = ZUniSwapV2Library.pairFor(address(factory), tokenA, tokenB);
        // transfer LP tokens from user to pair contract
        ZUniSwapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);
        // burn LP tokens
        (amountA, amountB) = ZUniSwapV2Pair(pair).burn(to);
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountB < amountBMin) revert InsufficientBAmount();
    }

    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = ZUniSwapV2Library.getReserves(
            address(factory),
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            // take desired amount as added liquidity if there is no reserve
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // try finding optimal amountB first
            uint256 amountBOptimal = ZUniSwapV2Library.quote(
                amountADesired, 
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal <= amountBMin) revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // find optimal amountA
                uint256 amountAOptimal = ZUniSwapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if (amountAOptimal < amountAMin) revert InsufficientAAmount();

                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert SafeTransferFailed();
    }
}
