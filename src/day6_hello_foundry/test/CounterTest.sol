// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { Counter } from "../src/Counter.sol";
import { ERC20, IERC20Errors, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KKToken is ERC20 {
    event BatchTransfer(address[] recipients, uint256[] amounts);

    constructor() ERC20("KK Token", "KK") {
        _mint(msg.sender, 1_000_000e18);
    }

    function batchTransfer(address[] memory recipients, uint256[] memory amounts) public {
        require(
            recipients.length == amounts.length, "KKToken: recipients and amounts length mismatch"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], amounts[i]);
        }

        emit BatchTransfer(recipients, amounts);
    }
}

contract KKTokenTest is Test {
    KKToken public token;
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");

    function setUp() public {
        vm.prank(admin);
        token = new KKToken();

        vm.prank(admin);
        token.transfer(alice, 1000000);
    }

    function testRevertBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 100
            )
        );
        token.transfer(alice, 100);
    }

    /**
     * forge-config: default.fuzz.runs = 5
     * forge-config: default.fuzz.max-test-rejects = 100000
     */
    function testBatchTransfer(address[] memory recipients, uint256[] memory amounts) public {
        //对随机取值数做有效约束
        uint256 total = 0;
        uint256 balance = token.balanceOf(alice);
        vm.assume(recipients.length == amounts.length);
        vm.assume(recipients.length < 100);
        for (uint256 i = 0; i < recipients.length; i++) {
            vm.assume(recipients[i] != address(0));
            vm.assume(amounts[i] != 0 && amounts[i] <= balance);
            total += amounts[i];
        }
        vm.assume(total <= token.balanceOf(alice));

        // 编写测试Log
        for (uint256 i = 0; i < recipients.length; i++) {
            vm.expectEmit(true, true, true, true, address(token));
            emit IERC20.Transfer(alice, recipients[i], amounts[i]);
        }

        vm.expectEmit(true, true, true, true, address(token));
        emit KKToken.BatchTransfer(recipients, amounts);

        vm.prank(alice);
        token.batchTransfer(recipients, amounts);
    }
}

contract CounterTest is Test {
    Counter public counter;
    address admin = makeAddr("admin");

    function setUp() public {
        vm.prank(admin);
        counter = new Counter();
        counter.setNumber(0);
    }

    function test_Increment() public {
        vm.startPrank(admin);

        counter.increment();
        assertEq(counter.number(), 1);
        counter.increment();
        vm.stopPrank();

        assertEq(counter.number(), 2);

        address alice = makeAddr("alice");
        console.log("before", alice, alice.balance); // 1000000000000000000
        vm.deal(alice, 1 ether);
        vm.deal(alice, 2 ether);
        console.log(alice, alice.balance); // 1000000000000000000
    }

    function testRevertWhenNotOwner() public {
        vm.expectRevert("only owner can increment");
        counter.increment();

        vm.prank(admin);
        counter.increment();

        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }

    function testAliceBalance() public {
        address user = 0x0d6D22E88d0C10a6D86edE07DCC0c0Df39DDa4AA;
        assertEq(user.balance, 2 ether);
    }
}
