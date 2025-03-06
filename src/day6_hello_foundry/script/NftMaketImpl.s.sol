pragma solidity ^0.8.20;

import {console,Script} from "forge-std/Script.sol";
import {NFTMarketImpl} from "../src/NFTMarketImpl.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

//forge script --chain sepolia NFTMarketImplScript --rpc-url https://eth-sepolia.api.onfinality.io/public --broadcast --account Admin
//forge verify-contract --chain-id 11155111 --etherscan-api-key xxxx 0x src/NFTMarketImpl.sol:NFTMarketImpl

contract NFTMarketImplScript is Script {

    //0x2E68D67cF8dC03a1615F8bdDD36FcE6a80E3918D 实现合约
    //0x6A63D8d9F45098547E00517B586d1875Cb0EEa5C 代理合约
    function run() public {
        vm.startBroadcast();
        // 使用 Upgrades 库部署实现合约和代理合约
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            address(new NFTMarketImpl()),
            abi.encodeCall(NFTMarketImpl.initialize, (0xaa5bc77916ce4a0e377F8F2bB9b0577798fE9beb))
        );
        console.log("NFTMarket Proxy deployed to:", proxy);
        vm.stopBroadcast();
    }


}