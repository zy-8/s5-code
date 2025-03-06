pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarketV1.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// 添加测试代币合约
contract TestERC20 is ERC20 {
    constructor() ERC20("TestERC20", "T20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// 添加测试 NFT 合约
contract TestERC721 is ERC721 {
    constructor() ERC721("TestERC721", "T721") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract NFTMarketV1Test is Test {
    bytes32 public DOMAIN_SEPARATOR;

    NFTMarketV1 public nftMarket;
    address public seller;
    uint256 public sellerKey;
    address public buyer;
    uint256 public buyerKey;
    TestERC20 public erc20;
    TestERC721 public erc721;

    function setUp() public {
        (seller, sellerKey) = makeAddrAndKey("Seller");
        (buyer, buyerKey) = makeAddrAndKey("Buyer");
        // 部署市场合约
        nftMarket = new NFTMarketV1();
        // 部署ERC20合约
        erc20 = new TestERC20();
        // 部署ERC721合约
        erc721 = new TestERC721();
        // 铸造ERC20代币
        erc20.mint(buyer, 1000);
        // 铸造ERC721 NFT
        erc721.mint(seller, 1);

        vm.deal(buyer, 1000 ether);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NFTMarket"),
                keccak256("1.0"),
                block.chainid,
                address(nftMarket)
            )
        );
    }
    //测试正例ETH支付
    function test_sellNFT_ETH() public {
        vm.startPrank(seller);
        erc721.approve(address(nftMarket), 1);

        // 构建EIP712签名数据
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.SELL_TYPEHASH(),
                address(erc721),
                1,
                100 ether,
                address(0),
                block.timestamp,
                block.timestamp + 1 days
            )
        );

        // 计算签名哈希
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );
        // 使用卖家私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.startPrank(buyer);
        // 买家支付ETH
        nftMarket.orderExecuted{value: 100 ether}(
            address(erc721),
            1,
            100 ether,
            address(0),
            block.timestamp,
            block.timestamp + 1 days,
            signature
        );
        vm.stopPrank();

        // 验证 NFT 是否转移给买家
        assertEq(erc721.ownerOf(1), buyer);
    }

    //测试正例ERC20支付
    function test_sellNFT_ERC20() public {
        vm.startPrank(seller);
        erc721.approve(address(nftMarket), 1);

        // 构建EIP712签名数据
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.SELL_TYPEHASH(),
                address(erc721),
                1,
                100,
                address(erc20),
                block.timestamp,
                block.timestamp + 1 days
            )
        );

        // 计算签名哈希
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );
        // 使用卖家私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.startPrank(buyer);
        erc20.approve(address(nftMarket), 100);
        nftMarket.executeOrder(
            address(erc721),
            1,
            100,
            address(erc20),
            block.timestamp,
            block.timestamp + 1 days,
            signature
        );
        vm.stopPrank();

        // 验证 NFT 是否转移给买家
        assertEq(erc721.ownerOf(1), buyer);
    }

    //测试反例
    function test_sellNFT_failed_ERC20() public {
        vm.startPrank(seller);
        erc721.approve(address(nftMarket), 1);

        // 构建EIP712签名数据
        bytes32 structHash = keccak256(
            abi.encode(
                nftMarket.SELL_TYPEHASH(),
                address(erc721),
                1,
                100,
                address(erc20),
                block.timestamp,
                block.timestamp + 1 days
            )
        );

        // 获取最终要签名的哈希
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );

        // 买家签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(buyer);
        // 预期签名信息错误 导致交易失败当前时间+2天 买家签名是当前时间+1天
        vm.expectRevert("Invalid signature");
        nftMarket.executeOrder(
            address(erc721),
            1,
            100,
            address(erc20),
            block.timestamp,
            block.timestamp + 2 days,
            signature
        );
        vm.stopPrank();

        // 验证 NFT 是否未转移
        assertEq(erc721.ownerOf(1), seller);
    }
}
