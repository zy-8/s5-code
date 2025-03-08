pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AirdopMerkleNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC20 is ERC20Permit {
    constructor() ERC20("Test Token", "TTK") ERC20Permit("Test Token") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract AirdopMerkleNFTTest is Test {
    AirdopMerkleNFT public airdopMerkleNFT;
    address public user1;
    uint256 public user1PrivateKey = 0xa3ff78b2faa7e1c996521151384b9400dd6f3458a70c1fb2c1393b8197d8abd5;
    TestERC20 public testERC20;

    function setUp() public {
        user1 = vm.addr(user1PrivateKey);
        console.log("Generated address:", user1);
        vm.startPrank(user1);
        testERC20 = new TestERC20();
        vm.stopPrank();
        bytes32 rootHash = 0x0bd1abfbca5006a9c51950a9cf02bdfdcfa8a5cfc0c91870360f4f171618fa1d;
        uint256 basePrice = 100;
        address payToken = address(testERC20);
        airdopMerkleNFT = new AirdopMerkleNFT(rootHash, basePrice, payToken);
    }

    function test_multicall() public {
        vm.startPrank(user1);
        bytes[] memory data = new bytes[](2);
        //构建permit签名
        bytes32 domainSeparator = testERC20.DOMAIN_SEPARATOR();
        bytes32 permitHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                address(user1),
                address(airdopMerkleNFT),
                50,
                testERC20.nonces(user1),
                block.timestamp + 1000
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, hash);

        data[0] = abi.encodeWithSelector(
            AirdopMerkleNFT.permitPrePay.selector, address(testERC20), 50, block.timestamp + 1000, v, r, s
        );

        bytes32[] memory proof = new bytes32[](3);
        proof[0] = 0x00f369b03139ffa987d43ef2453e4b14a9a184bc669bd087e69c25c51332c32f;
        proof[1] = 0xafe8c6eb446c5e2ae4728675ecc904b911ba9edaff8f928bbe51a29dd4ce1e05;
        proof[2] = 0xe532bea76eb3f6c701b02dbfdcbc77fc6d89a3ed2c4a30bd962fbdea284716a2;
        data[1] = abi.encodeWithSelector(AirdopMerkleNFT.claimNFT.selector, proof);

        airdopMerkleNFT.multicall(data);

        assertEq(airdopMerkleNFT.balanceOf(user1), 1);
        assertEq(testERC20.balanceOf(address(airdopMerkleNFT)), 50);
        vm.stopPrank();
    }

    function test_claimNFT() public {
        vm.startPrank(user1);
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = 0x00f369b03139ffa987d43ef2453e4b14a9a184bc669bd087e69c25c51332c32f;
        proof[1] = 0xafe8c6eb446c5e2ae4728675ecc904b911ba9edaff8f928bbe51a29dd4ce1e05;
        proof[2] = 0xe532bea76eb3f6c701b02dbfdcbc77fc6d89a3ed2c4a30bd962fbdea284716a2;
        airdopMerkleNFT.claimNFT(proof);
        vm.stopPrank();
    }

    bytes32 private constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function test_permitPrePay() public {
        vm.startPrank(user1);
        //构建permit签名
        bytes32 domainSeparator = testERC20.DOMAIN_SEPARATOR();
        bytes32 permitHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                address(user1),
                address(airdopMerkleNFT),
                100,
                testERC20.nonces(user1),
                block.timestamp + 1000
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, hash);
        airdopMerkleNFT.permitPrePay(address(testERC20), 100, block.timestamp + 1000, v, r, s);
        vm.stopPrank();
    }
}
