// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC777Recipient {
    function transferWithCallback(address from, uint256 amount) external;
}