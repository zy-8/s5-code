pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenBank2612} from "../src/TokenBank2612.sol";
import {ERC2612} from "../src/ERC2612.sol";

contract TokenBank2612Test is Test {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    address owner;
    TokenBank2612 public tokenBank;
    ERC2612 public token;
    uint256 ownerPrivateKey = 0x1234; // 使用一个测试私钥
    function setUp() public {
        token = new ERC2612("USDT", "USDT");
        owner = vm.addr(ownerPrivateKey);
        token.mint(owner, 1000000e18);
        tokenBank = new TokenBank2612(address(token));
    }

    function testPermitDeposit() public {
        vm.startPrank(owner);

        console.log("owner", owner);
        console.log("msg.sender", msg.sender);

        //签名
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                address(tokenBank),
                100,
                token.nonces(owner),
                block.timestamp + 1000
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        // 使用私钥生成地址
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        tokenBank.permitDeposit(100, owner, block.timestamp + 1000, v, r, s);

        assertEq(tokenBank.balances(owner), 100);
        assertEq(token.balanceOf(address(tokenBank)), 100);
        assertEq(token.nonces(owner), 1);

        vm.stopPrank();
    }

    //测试permitDeposit反例
    function testPermitDepositRevert() public {
        vm.startPrank(owner);

        //签名
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                address(tokenBank),
                100,
                token.nonces(owner),
                block.timestamp + 1000
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        // 使用错误的私钥签名
        uint256 wrongPrivateKey = ownerPrivateKey + 1;
        address wrongSigner = vm.addr(wrongPrivateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, hash);

        // 预期交易会失败
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC2612InvalidSigner(address,address)",
                wrongSigner,
                owner
            )
        );
        tokenBank.permitDeposit(100, owner, block.timestamp + 1000, v, r, s);

        vm.stopPrank();

        // 验证状态没有改变
        assertEq(tokenBank.balances(owner), 0);
        assertEq(token.balanceOf(address(tokenBank)), 0);
        assertEq(token.nonces(owner), 0);
    }
}
