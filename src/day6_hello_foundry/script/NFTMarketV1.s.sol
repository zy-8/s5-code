// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/NFTMarketV1.sol";

//forge script --chain sepolia NFTMarketV1Script --rpc-url https://eth-sepolia.api.onfinality.io/public --broadcast --account Admin
//forge verify-contract --chain-id 11155111 --etherscan-api-key XXXXXXXX 0x src/NFTMarketV1.sol:NFTMarketV1

contract NFTMarketV1Script is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        NFTMarketV1 nftMarket = new NFTMarketV1();
        vm.stopBroadcast();
    }
}