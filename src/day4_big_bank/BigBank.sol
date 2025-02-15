// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Bank.sol";
import "./IBank.sol";

//BigBank继承Bank合约
contract BigBank is Bank {
    //转账金额不足异常
    error InsufficientAmount();
    error NoAccess();

    //判断转账金额是否小于 0.001eth
    modifier verifyAmont() {
        if (msg.value < 0.001 ether) revert InsufficientAmount();
        _;
    }

    //判断是否为管理员并且不能为空地址
    modifier onlyOwner(address newAdmin) {
        if (msg.sender != admin && newAdmin != address(0)) revert NoAccess();
        _;
    }

    //重写Bank合约的receive方法 增加金额判断条件 不能少于0.001eth
    receive() external payable override verifyAmont {
        balanceOf[msg.sender] += msg.value;
        updateTopUser(msg.sender, balanceOf[msg.sender]);
    }

    //更新管理员
    function updateAdmin(address newAdmin) external onlyOwner(newAdmin) {
        admin = newAdmin;
    }
}
