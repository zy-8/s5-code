pragma solidity ^0.8.0;

import {MultipleContracts} from "../src/MultipleContracts.sol";
import {Test} from "forge-std/Test.sol";

contract MultipleContractsTest is Test {
    MultipleContracts public multipleContracts;
    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        multipleContracts = new MultipleContracts(owners, 2);
        //设置合约余额
        vm.deal(address(multipleContracts), 10000 ether);
    }

    //测试提交交易
    function test_submitTransaction() public {
        // owner1 提交交易
        vm.prank(owner1);
        multipleContracts.submitTransaction(
            address(1), // 目标地址
            1 ether, // 转账金额
            "" // 空数据
        );
        // owner1 确认交易
        vm.prank(owner1);
        multipleContracts.confirmTransaction(0);

        // 验证确认状态
        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = multipleContracts.transactions(0);
        assertEq(to, address(1));
        assertEq(value, 1 ether);
        assertEq(data, "");
        assertEq(executed, false);
        assertEq(numConfirmations, 1);
    }

    //测试确认交易
    function test_confirmTransaction() public {
        vm.prank(owner1);
        // 提交交易
        multipleContracts.submitTransaction(address(1), 100, "");

        // 两个所有者确认交易
        vm.prank(owner2);
        multipleContracts.confirmTransaction(0);

        vm.prank(owner3);
        multipleContracts.confirmTransaction(0);

        // 验证交易状态
        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = multipleContracts.transactions(0);

        assertEq(to, address(1));
        assertEq(value, 100);
        assertEq(data, "");
        assertEq(executed, false);
        assertEq(numConfirmations, 2);
    }

    //测试执行交易
    function test_executeTransaction() public {
        //发起提案
        vm.prank(owner1);
        multipleContracts.submitTransaction(address(1), 100, "");
        vm.prank(owner2);
        multipleContracts.confirmTransaction(0);
        vm.prank(owner3);
        multipleContracts.confirmTransaction(0);
        //执行交易
        vm.prank(owner1);
        multipleContracts.executeTransaction(0);
        //验证交易状态
        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = multipleContracts.transactions(0);
        assertEq(to, address(1));
        assertEq(value, 100);
        assertEq(data, "");
        assertEq(executed, true);
        assertEq(numConfirmations, 2);
    }

    //测试撤销交易
    function test_revokeTransaction() public {
        vm.prank(owner1);
        //发起提案
        multipleContracts.submitTransaction(address(1), 100, "");
        vm.prank(owner2);
        //确认交易
        multipleContracts.confirmTransaction(0);
        vm.prank(owner3);
        //确认交易
        multipleContracts.confirmTransaction(0);
        //撤销交易
        vm.prank(owner1);
        multipleContracts.revokeTransaction(0);

        //验证交易状态
        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = multipleContracts.transactions(0);

        assertEq(to, address(1));
        assertEq(value, 100);
        assertEq(data, "");
        assertEq(executed, false);
        assertEq(numConfirmations, 1);  
    }

    //测试获取多签持有人地址数组
    function test_getOwners() public {
        address[] memory owners = multipleContracts.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }
}
