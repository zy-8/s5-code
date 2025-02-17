// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenBank.sol";

contract TokenBankV2 is TokenBank {

    constructor(address _token) TokenBank(_token) {}

    function tokensReceived(address sender,uint amount) external {
        balances[sender] += amount;
    }

}