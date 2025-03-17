pragma solidity ^0.8.13;

import {AutoBank} from "../src/AutoBank.sol";
import {Script} from "forge-std/Script.sol";

//forge script --chain sepolia /script/AutoBank.s.sol --rpc-url https://eth-sepolia.api.onfinality.io/public --broadcast --account Admin
//forge verify-contract --chain-id 11155111 --etherscan-api-key xxxx 0x src/AutoBank.sol:AutoBank


contract AutoBankScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        AutoBank autoBank = new AutoBank();
        vm.stopBroadcast();
    }
}