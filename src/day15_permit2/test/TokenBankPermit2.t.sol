// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBankPermit2.sol";
import "../src/Permit2.sol";
import "../src/interfaces/ISignatureTransfer.sol";
import "../src/interfaces/IPermit2.sol";
import "../src/libraries/PermitHash.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TokenBankPermit2Test is Test {
    TestToken public token;
    Permit2 public permit2;
    TokenBankPermit2 public tokenBank;
    address owner = makeAddr("owner");
    address user;
    uint256 ownerPrivateKey = 1;
    uint256 userPrivateKey = 2;

    function setUp() public {
        vm.startPrank(owner);
        //创建测试代币
        token = new TestToken();
        user = vm.addr(userPrivateKey);
        //铸造测试代币
        token.mint(user, 1000);
        //创建permit2合约
        permit2 = new Permit2();
        //创建tokenBank合约
        tokenBank = new TokenBankPermit2(address(permit2));
        vm.stopPrank();
    }

    function testPermitDeposit() public {
        vm.startPrank(user);

        // 验证余额
        assertEq(token.balanceOf(user), 1000, "User should have 1000 tokens");

        // 授权permit2合约可以转移代币
        token.approve(address(permit2), type(uint256).max);

        uint256 amount = 100;
        uint256 nonce = 1;
        uint256 deadline = block.timestamp + 1000;

        // 构建permit数据
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });

        // 使用 permit2 的 DOMAIN_SEPARATOR
        bytes32 domainSeparator = permit2.DOMAIN_SEPARATOR();

        // 计算 token permissions 的哈希值
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
        );

        // 计算 permitTransferFromHash
        bytes32 permitTransferFromHash = keccak256(
            abi.encode(
                PermitHash._PERMIT_TRANSFER_FROM_TYPEHASH,
                tokenPermissionsHash,
                address(tokenBank),
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 msgHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, permitTransferFromHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 调用depositWithPermit2函数
        tokenBank.depositWithPermit2(address(token), amount, nonce, deadline, signature);
        vm.stopPrank();
    }
}
