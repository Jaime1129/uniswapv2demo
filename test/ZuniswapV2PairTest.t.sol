// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ZUniSwapV2Pair} from "../src/ZuniSwapV2Pair.sol";
import "./mocks/ERC20Mintable.sol";

contract TestUser {
    function provideLiquidity(
        address pairAddress_,
        address token0Address_,
        address token1Address_,
        uint256 amount0_,
        uint256 amount1_
    ) public {
        ERC20(token0Address_).transfer(pairAddress_, amount0_);
        ERC20(token1Address_).transfer(pairAddress_, amount1_);

        ZUniSwapV2Pair(pairAddress_).mint(address(this));
    }

    function withdrawLiquidity(address pairAddress_) public {
        ZUniSwapV2Pair(pairAddress_).burn(address(this));
    }
}

contract ZUniSwapV2PairTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    ZUniSwapV2Pair pair;
    TestUser testUser;

    function setUp() public {
        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");
        pair = new ZUniSwapV2Pair();
        pair.initialize(address(token0), address(token1));
        testUser = new TestUser();
        token0.mint(10 ether, address(testUser));
        token1.mint(10 ether, address(testUser));
        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));
    }

    function testMintBootstrap() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this));

        // check LP token amount
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserve(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintWithLiquidity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this));

        // check LP token amount
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserve(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);

        token0.transfer(address(pair), 3 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint(address(this));

        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertReserve(4 ether, 3 ether);
        assertEq(pair.totalSupply(), 3 ether);
    }

    function assertReserve(uint112 res0, uint112 res1) internal view {
        (uint112 reserve0, uint112 reserve1) = pair.getReserves();
        assertEq(reserve0, res0);
        assertEq(reserve1, res1);
    }

    function testBurn() public {
        testMintBootstrap();
        
        pair.transferFrom(msg.sender, address(pair), pair.balanceOf(address(this)));
        pair.burn(address(this));

        assertEq(pair.totalSupply(), 1000);
        assertEq(pair.balanceOf(address(this)), 0);
        assertReserve(1000, 1000);
        assertEq(token0.balanceOf(address(this)), 10 ether - 1000);
        assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnDifferentUsers() public {
        testUser.provideLiquidity(
            address(pair),
            address(token0),
            address(token1),
            1 ether,
            1 ether
        );

        // total LP tokens = 1 ether, belonging to test user
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.balanceOf(address(testUser)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        // total LP tokens = 2 ether. 1 ether to test user, 1 ether to this.
        pair.mint(address(this)); 

        assertEq(pair.balanceOf(address(this)), 1 ether);
        assertEq(pair.totalSupply(), 2 ether);
        assertReserve(3 ether, 2 ether);

        pair.transferFrom(msg.sender, address(pair), pair.balanceOf(address(this)));
        pair.burn(address(this));

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), 1 ether);
        assertReserve(1.5 ether, 1 ether);
        // 0.5 ether of token0 is lost
        assertEq(token0.balanceOf(address(this)), 9.5 ether);
        assertEq(token1.balanceOf(address(this)), 10 ether);
    }
}
