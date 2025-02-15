// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBank.sol";

contract Admin {
    error NoAccess();

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NoAccess();
        _;
    }

    receive() external payable { }

    //初始化构造函数
    constructor() {
        owner = msg.sender;
    }

    //adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 合约内的资金转移到 Admin 合约地址
    function withdraw(IBank bank, uint256 amount) external onlyOwner {
        bank.withdraw(amount);
    }
}
