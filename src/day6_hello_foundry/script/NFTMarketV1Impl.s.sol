// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {NFTMarketV1Impl} from "../src/NFTMarketV1Impl.sol";

import "forge-std/console.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

//forge script --chain sepolia script/NFTMarketV1Impl.s.sol:NFTMarketV1ImplScript --rpc-url https://eth-sepolia.api.onfinality.io/public --broadcast --account Admin
//forge verify-contract --chain-id 11155111 --etherscan-api-key xxx 0x src/NFTMarketV1Impl.sol:NFTMarketV1Impl

contract NFTMarketV1ImplScript is Script {
    function setUp() public {}

    function run() public {

        vm.startBroadcast();

        // 代理合约地址（使用与V1相同的地址）
        address proxy = address(0x6A63D8d9F45098547E00517B586d1875Cb0EEa5C);

        // 部署新的实现合约并升级
        address newImpl = address(new NFTMarketV1Impl());

        // 使用与V1相同的支付代币地址进行初始化
        bytes memory initData = abi.encodeCall(
            NFTMarketV1Impl.initialize,
            (0xaa5bc77916ce4a0e377F8F2bB9b0577798fE9beb)
        );

        UnsafeUpgrades.upgradeProxy(proxy, newImpl, initData);

        // 获取新的实现合约地址
        address implAddressV1 = UnsafeUpgrades.getImplementationAddress(proxy);

        //NFTMarketV1Impl upgraded 0x6A63D8d9F45098547E00517B586d1875Cb0EEa5C
        //NFTMarketV1Impl implementation address 0x142710e70a5DD77E56EDccd16060746d4da19D1f
        console.log("NFTMarketV1Impl upgraded", proxy);
        console.log("NFTMarketV1Impl implementation address", implAddressV1);

        vm.stopBroadcast();
    }
}
