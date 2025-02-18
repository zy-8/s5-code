// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenBank.sol";

contract TokenBankV2 is TokenBank {
    constructor(address _token) TokenBank(_token) {}

    modifier isToken() {
        require(msg.sender == address(token), "no token");
        _;
    }

    function tokensReceived(address sender, uint256 amount) internal isToken {
        balances[sender] += amount;
    }
}
