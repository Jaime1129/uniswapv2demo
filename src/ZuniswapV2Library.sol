// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ZuniswapV2Pair.sol";
import "./ZuniswapV2Factory.sol";

// libraries don’t have state: their functions are executed in caller’s state via DELEGATECALL.
library ZUniSwapV2Library {
    error InsufficientAmount();
    error InsufficientPairLiquidity();
    error InvalidPath();

    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pairAddress) {
        // ZUniSwapV2Factory(factory).pairs(tokenA, tokenB) will execute an external contract call, which is a little more expensive
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        // 0xff – this first byte helps to avoid collisions with CREATE opcode. (More details are in EIP-1014.)
        // factoryAddress – factory that was used to deploy the pair.
        // salt – token addressees sorted and hashed.
        // hash of pair contract bytecode – we hash creationCode to get this value.
        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(ZUniSwapV2Pair).creationCode)
                        )
                    )
                )
            )
        );
    }

    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1) = ZUniSwapV2Pair(
            pairFor(factoryAddress, token0, token1)
        ).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0)
            revert InsufficientPairLiquidity();

        return (amountIn * reserveOut) / reserveIn;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0)
            revert InsufficientPairLiquidity();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) public returns (uint256[] memory) {
        if (path.length < 2) revert InvalidPath();
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserve0, uint256 reserve1) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserve0, reserve1);
        }
        return amounts;
    }

    function _sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
