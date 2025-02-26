// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC2612} from "../src/ERC2612.sol";

contract ERC2612Test is Test {
    address owner = makeAddr("owner");
    address spender = makeAddr("spender");
    ERC2612 public erc2612;
    uint256 ownerPrivateKey = 0x1234; // 使用一个测试私钥

    function setUp() public {
        // 使用私钥生成地址
        owner = vm.addr(ownerPrivateKey);

        vm.prank(owner);
        erc2612 = new ERC2612("USDT", "USDT");
        erc2612.mint(owner, 1000000e18);
    }

    function testPermit() public {
        uint256 value = 1000;
        uint256 deadline = block.timestamp + 1000;

        bytes32 domainSeparator = erc2612.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                owner,
                spender,
                value,
                erc2612.nonces(owner),
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        // 使用 ownerPrivateKey 进行签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        erc2612.permit(owner, spender, value, deadline, v, r, s);
        assertEq(erc2612.allowance(owner, spender), value);
    }
}
