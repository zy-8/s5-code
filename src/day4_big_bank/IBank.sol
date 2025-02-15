// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    struct User {
        address userAddr;
        uint256 balance;
    }

    //取款
    function withdraw(uint256 amount) external;

    //获取转账前三名用户
    function getTopUsers() external view returns (User[3] memory);
}
