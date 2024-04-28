// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ZuniswapV2Factory.sol";
import "./ZuniswapV2Pair.sol";

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
    ) public returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    ) {
        // if pair contract doesn't exist, create it
        if (factory.pairs(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        
    }

    function _calculateLiquidity(
                address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amount0, uint256 amount1) {
        // todo
    }
}