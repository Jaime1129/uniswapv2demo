// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ZuniswapV2Pair.sol";

error IdenticalAddresses();
error PairExists();
error ZeroAddress();

contract ZUniSwapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    // token => (token => pair)
    mapping(address => mapping(address => address)) public pairs;

    address[] public allPairs;

    function createPair(
        address tokenA,
        address tokenB
    ) public returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddresses();

        // avoid duplicate pair
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();

        // pair already exists
        if (pairs[token0][token1] != address(0)) revert PairExists();

        // use CREATE2 opcode to deploy pair contracts
        // get the bytecode of Pair contract
        bytes memory bytecode = type(ZUniSwapV2Pair).creationCode;
        // take the sha256 of token0 and token1 as salt, which determines the new contract's address
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // This section uses inline assembly, which allows for more direct control over EVM (Ethereum Virtual Machine) operations
        assembly {
            // create2 parameters:
            // 0: The amount of ETH sent with the contract creation. 0 means no ETH is sent.
            // add(bytecode, 0x20):This calculates the starting point of the actual contract bytecode. 0x20 (32 in decimal) is added to skip the first 32 bytes of the bytecode array, which store the length of the bytecode array itself.
            // mload(bytecode): This loads the length of the bytecode (first 32 bytes of bytecode, hence why it was skipped in the previous parameter).
            // salt: The unique salt calculated earlier. This salt ensures the deterministic generation of the contract's address.
            pair := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        // create2 cannot pass parameter to constructor, need call initialize function after creation
        ZUniSwapV2Pair(pair).initialize(token0, token1);

        // save pair to storage
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
