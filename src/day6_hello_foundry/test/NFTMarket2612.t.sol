// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTMarket2612.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract MockToken is ERC20Permit {
    constructor() ERC20("Mock Token", "MTK") ERC20Permit("Mock Token") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract NFTMarket2612Test is Test {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    using ECDSA for bytes32;
    
    NFTMarket2612 public market;
    MockNFT public nft;
    MockToken public token;
    
    address owner;
    uint256 ownerPrivateKey;
    address seller;
    address buyer;
    uint256 buyerPrivateKey;
    uint256 tokenId;

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
        market = new NFTMarket2612(address(token));
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

        vm.startPrank(owner);
        // 项目方签名白名单 - 只对地址和 nonce 签名
        bytes32 whitelistHash = keccak256(
            abi.encodePacked(
                buyer,                    // 白名单地址
                market.nonces(buyer)      // nonce 防重放
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", whitelistHash)
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerPrivateKey, message);
        bytes memory signature = abi.encodePacked(r1, s1, v1);
        vm.stopPrank();

        // 买家签名 permit
        vm.startPrank(buyer);
        uint256 deadline = block.timestamp + 1000;
        
        bytes32 permitHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                buyer,
                address(market),
                price,
                token.nonces(buyer),
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), permitHash)
        );
        
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(buyerPrivateKey, digest);

        // 买家购买 NFT
        market.permitBuy(
            address(nft),
            tokenId,
            deadline,
            v2,
            r2,
            s2,
            signature
        );

        // 验证购买结果
        assertEq(nft.ownerOf(tokenId), buyer);
        vm.stopPrank();
    }
}
