// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Factory.sol";

contract FactoryTest is Test {
    Factory factory;
    TokenImpl tokenImpl;
    
    address user = makeAddr("user");
    address creator = makeAddr("creator");
    address project = makeAddr("project");

    function setUp() public {
        // 给测试账户充值
        vm.deal(user, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(project, 100 ether);

        // 项目方部署合约
        vm.startPrank(project);
        tokenImpl = new TokenImpl();
        factory = new Factory(address(tokenImpl));
        vm.stopPrank();
    }

    // 测试部署代币
    function test_deployToken() public {
        vm.startPrank(creator);
        
        // 创建代币
        address tokenAddr = factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST",
                totalSupply: 1000000,
                perMint: 1000,
                price: 1 ether
            })
        );

        // 验证代币信息
        assertEq(TokenImpl(tokenAddr).symbol(), "TEST");
        assertEq(factory.tokenToCreator(tokenAddr), creator);
        
        vm.stopPrank();
    }

    // 测试铸造代币
    function test_mintToken() public {
        // 创建者部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST",
                totalSupply: 1000000,
                perMint: 1000,
                price: 1 ether
            })
        );
        vm.stopPrank();

        // 记录初始余额
        uint256 creatorBalanceBefore = creator.balance;
        uint256 projectBalanceBefore = project.balance;

        // 用户铸造代币
        vm.startPrank(user);
        factory.mintToken{value: 1 ether}(tokenAddr);

        // 验证代币铸造
        assertEq(TokenImpl(tokenAddr).balanceOf(user), 1000);
        
        // 验证费用分配 (90% 给创建者, 10% 给项目方)
        assertEq(creator.balance - creatorBalanceBefore, 0.9 ether);
        assertEq(project.balance - projectBalanceBefore, 0.1 ether);
        
        vm.stopPrank();
    }

    // 测试重复部署
    function test_RevertWhen_DeployTwice() public {
        vm.startPrank(creator);
        
        // 第一次部署成功
        factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST1",
                totalSupply: 1000000,
                perMint: 1000,
                price: 1 ether
            })
        );

        // 第二次部署应该失败
        vm.expectRevert("Address is not valid");
        factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST2",
                totalSupply: 1000000,
                perMint: 1000,
                price: 1 ether
            })
        );
        
        vm.stopPrank();
    }

    // 测试铸造超过总供应量
    function test_RevertWhen_ExceedTotalSupply() public {
        // 创建者部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST",
                totalSupply: 1500,      // 总供应量1500
                perMint: 1000,          // 每次铸造1000
                price: 1 ether
            })
        );
        vm.stopPrank();

        vm.startPrank(user);
        // 第一次铸造1000个
        factory.mintToken{value: 1 ether}(tokenAddr);
        
        // 第二次铸造应该失败，因为剩余量不足1000
        vm.expectRevert("Total supply is not enough");
        factory.mintToken{value: 1 ether}(tokenAddr);
        
        vm.stopPrank();
    }

    // 测试支付金额不足
    function test_RevertWhen_InsufficientPayment() public {
        // 创建者部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST",
                totalSupply: 1000000,
                perMint: 1000,
                price: 1 ether
            })
        );
        vm.stopPrank();

        vm.startPrank(user);
        // 支付金额不足应该失败
        vm.expectRevert("Price is not enough");
        factory.mintToken{value: 0.5 ether}(tokenAddr);
        
        vm.stopPrank();
    }

    // 测试最小代理合约的大小
    function test_CloneByteCodeSize() public {
        // 部署一个新代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployToken(
            Factory.TokenInfo({
                symbol: "TEST",
                totalSupply: 1000000,
                perMint: 1000,
                price: 1 ether
            })
        );
        vm.stopPrank();

        // 获取代币合约的字节码
        uint256 size;
        address implementation = factory.tokenImpl();
        
        assembly {
            size := extcodesize(tokenAddr)
        }
        console.log("Clone contract size:", size, "bytes");
        
        uint256 implSize;
        assembly {
            implSize := extcodesize(implementation)
        }
        console.log("Implementation contract size:", implSize, "bytes");
        
        // 最小代理合约的大小应该远小于实现合约
        assertTrue(size < implSize);
        // EIP-1167 最小代理大约45字节
        assertTrue(size < 50);
    }
}
