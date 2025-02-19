// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Bank.sol";  // 导入事件

contract BankTest is Test {
    Bank public bank;
    address user = makeAddr("user");
    uint256 constant DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        bank = new Bank();
    }

    function test_DepositETH() public {
        // 给测试用户一些 ETH
        vm.deal(user, DEPOSIT_AMOUNT);
        
        // 记录用户初始存款额
        uint256 balanceBefore = bank.balanceOf(user);
        console.log("balanceBefore", balanceBefore);
        
        // 模拟用户操作
        vm.prank(user);
        
        // 设置预期事件
        vm.expectEmit(true, false, false, true);
        // 发射事件
        emit Bank.Deposit(user, DEPOSIT_AMOUNT);
        
        // 执行存款
        bank.depositETH{value: DEPOSIT_AMOUNT}();
        console.log("balanceAfter", bank.balanceOf(user));
        // 断言检查存款后余额
        assertEq(
            bank.balanceOf(user),
            balanceBefore + DEPOSIT_AMOUNT,
            "Balance should increase by deposit amount"
        );
    }
}