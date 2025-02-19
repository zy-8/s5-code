// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test,console} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TokenBankTest is Test {
    TokenBank public bank;
    TestToken public token;
    address user = makeAddr("user");
    uint256 constant AMOUNT = 100 ether;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function setUp() public {
        token = new TestToken();
        bank = new TokenBank(address(token));
        
        // 给用户铸造代币并授权
        token.mint(user, AMOUNT * 2);

        console.log("token.balanceOf(user)", token.balanceOf(user));
        vm.prank(user);
        token.approve(address(bank), type(uint256).max);
    }

    function test_Deposit() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit Deposit(user, AMOUNT);
        
        bank.deposit(AMOUNT);
        
        assertEq(bank.balances(user), AMOUNT);
        assertEq(token.balanceOf(address(bank)), AMOUNT);
    }

    function test_Withdraw() public {
        // 先存款
        vm.prank(user);
        bank.deposit(AMOUNT);
        
        // 后取款
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(user, AMOUNT);
        
        bank.withdraw(AMOUNT);
        
        assertEq(bank.balances(user), 0);
        assertEq(token.balanceOf(address(bank)), 0);
    }

    function test_RevertWhen_WithdrawingTooMuch() public {
        vm.prank(user);
        bank.deposit(AMOUNT);
        
        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(AMOUNT + 1);
    }

    function test_RevertWhen_WithdrawingWithoutBalance() public {
        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(1);
    }
} 