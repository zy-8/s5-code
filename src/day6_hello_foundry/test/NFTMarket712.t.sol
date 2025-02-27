// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTMarket712.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract NFTMarket712Test is Test, EIP712 {
    bytes32 public constant WHITELIST_TYPEHASH =
        keccak256("WhitelistPermit(address buyer,uint256 nonce)");

    using ECDSA for bytes32;

    NFTMarket712 public market;
    MockNFT public nft;
    MockToken public token;

    address owner;
    uint256 ownerPrivateKey;
    address seller;
    address buyer;
    uint256 buyerPrivateKey;
    uint256 tokenId;

    constructor() EIP712("NFTMarket", "1.0") {}

    function setUp() public {
        // 生成项目方的私钥和地址
        ownerPrivateKey = 0x1234;
        owner = vm.addr(ownerPrivateKey);

        // 生成买家的私钥和地址
        buyerPrivateKey = 0x5678;
        buyer = vm.addr(buyerPrivateKey);

        seller = makeAddr("seller");
        tokenId = 1;

        // 部署合约
        vm.startPrank(owner);
        token = new MockToken();
        market = new NFTMarket712(address(token));
        nft = new MockNFT();
        // 铸造 NFT 给卖家
        nft.mint(seller, tokenId);
        // 给买家转 token
        token.transfer(buyer, 1000 * 10 ** 18);
        vm.stopPrank();
    }

    function testPermitBuy() public {
        uint256 price = 100 * 10 ** 18;

        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, price);
        vm.stopPrank();

        // 项目方签名白名单 - 使用 EIP712
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("NFTMarket"),
                keccak256("1.0"),
                block.chainid,
                address(market)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                market.WHITELIST_TYPEHASH(),
                buyer,
                market.nonces(buyer)
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 买家购买 NFT
        vm.startPrank(buyer);
        // 买家先授权代币
        token.approve(address(market), price);
        // 使用白名单签名购买
        market.permitBuy(address(nft), tokenId, signature);

        // 验证购买结果
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(buyer), 900 * 10 ** 18);
        assertEq(token.balanceOf(seller), price);
        vm.stopPrank();
    }

    function testRevertWhenNotWhitelisted() public {
        uint256 price = 100 * 10 ** 18;

        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, price);
        vm.stopPrank();

        // 使用错误的私钥签名
        uint256 wrongPrivateKey = 0x9999;
        bytes32 structHash = keccak256(
            abi.encode(
                market.WHITELIST_TYPEHASH(),
                buyer,
                market.nonces(buyer)
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 买家尝试购买 NFT
        vm.startPrank(buyer);
        token.approve(address(market), price);
        vm.expectRevert("Invalid whitelist signature");
        market.permitBuy(address(nft), tokenId, signature);
        vm.stopPrank();
    }
}
