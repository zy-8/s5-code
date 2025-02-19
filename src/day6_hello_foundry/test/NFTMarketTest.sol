// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟 NFT 合约
contract MockNFT is ERC721 {
    uint256 private _tokenIds;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        _tokenIds++;
        _mint(to, _tokenIds);
        return _tokenIds;
    }
}

// 模拟 ERC20 代币合约
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract NFTMarketTest is Test {
    NFTMarket public market;
    MockNFT public nft;
    MockERC20 public paymentToken;

    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    uint256 price = 100 * 10 ** 18;

    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event NFTPurchased(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    function setUp() public {
        // 部署合约
        paymentToken = new MockERC20();
        market = new NFTMarket(address(paymentToken));
        nft = new MockNFT();

        // 设置初始余额
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);

        // 给买家转入代币
        paymentToken.transfer(buyer, 500 * 10 ** 18);
    }

    // 测试成功上架 NFT
    function test_ListNFT() public {
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);

        // 验证事件
        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(nft), tokenId, seller, price);
        market.list(address(nft), tokenId, price);

        // 验证上架信息
        (address listedSeller, uint256 listedPrice, bool isActive) = market.getListing(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(isActive);
        assertEq(nft.ownerOf(tokenId), address(market));
        vm.stopPrank();
    }

    // 测试成功购买 NFT
    function test_BuyNFT() public {
        // 上架 NFT
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, price);
        vm.stopPrank();

        // 买家购买
        vm.startPrank(buyer);
        uint256 buyerInitialBalance = paymentToken.balanceOf(buyer);
        uint256 sellerInitialBalance = paymentToken.balanceOf(seller);

        paymentToken.approve(address(market), price);
        
        // 验证事件
        vm.expectEmit(true, true, true, true);
        emit NFTPurchased(address(nft), tokenId, buyer, price);
        market.buyNFT(address(nft), tokenId);

        // 验证状态
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(buyer), buyerInitialBalance - price);
        assertEq(paymentToken.balanceOf(seller), sellerInitialBalance + price);
        
        (, , bool isActive) = market.getListing(address(nft), tokenId);
        assertFalse(isActive);
        vm.stopPrank();
    }

    // 测试零价格上架失败
    function test_RevertWhen_ListingWithZeroPrice() public {
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);

        vm.expectRevert("Price must be greater than 0");
        market.list(address(nft), tokenId, 0);
        vm.stopPrank();
    }

    // 测试无效 NFT 合约地址
    function test_RevertWhen_ListingWithInvalidNFTContract() public {
        vm.startPrank(seller);
        vm.expectRevert("Invalid NFT contract");
        market.list(address(0), 1, price);
        vm.stopPrank();
    }

    // 测试未授权上架失败
    function test_RevertWhen_ListingWithoutApproval() public {
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        // 不调用 approve

        vm.expectRevert("NFT not approved");
        market.list(address(nft), tokenId, price);
        vm.stopPrank();
    }

    // 测试购买自己的 NFT 失败
    function test_RevertWhen_BuyingOwnNFT() public {
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, price);

        paymentToken.approve(address(market), price);
        vm.expectRevert("Cannot buy your own NFT");
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();
    }

    // 测试购买未上架的 NFT 失败
    function test_RevertWhen_BuyingNonListedNFT() public {
        uint256 tokenId = nft.mint(seller);

        vm.startPrank(buyer);
        paymentToken.approve(address(market), price);
        vm.expectRevert("NFT not listed");
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();
    }

    // 测试重复购买已售出的 NFT 失败
    function test_RevertWhen_BuyingSoldNFT() public {
        // 上架并首次购买
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        paymentToken.approve(address(market), price);
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();

        // 创建新买家尝试购买
        address newBuyer = makeAddr("newBuyer");
        deal(address(paymentToken), newBuyer, price);

        vm.startPrank(newBuyer);
        paymentToken.approve(address(market), price);
        vm.expectRevert("NFT not listed");
        market.buyNFT(address(nft), tokenId);
        vm.stopPrank();
    }

    // 模糊测试：随机价格和买家
    /**
     * forge-config: default.fuzz.runs = 1024
     * forge-config: default.fuzz.max-test-rejects = 500
     */
    function testFuzz_ListAndBuyWithRandomPrice(
        address randomBuyer,
        uint256 randomPrice
    ) public {
        // 排除特殊地址
        vm.assume(randomBuyer != address(0));
        vm.assume(randomBuyer != seller);
        vm.assume(randomBuyer != address(market));
        vm.assume(randomBuyer != address(paymentToken));
        vm.assume(randomBuyer.code.length == 0);

        // 限制价格范围：0.01-10000 token
        randomPrice = bound(randomPrice, 0.01 ether, 10000 ether);

        // 上架
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, randomPrice);
        vm.stopPrank();

        // 购买
        deal(address(paymentToken), randomBuyer, randomPrice);
        vm.startPrank(randomBuyer);
        paymentToken.approve(address(market), randomPrice);
        market.buyNFT(address(nft), tokenId);

        // 验证
        assertEq(nft.ownerOf(tokenId), randomBuyer);
        assertEq(paymentToken.balanceOf(randomBuyer), 0);
        assertEq(paymentToken.balanceOf(seller), randomPrice);
        vm.stopPrank();
    }

    // 不变性测试：市场合约不持有代币
    function invariant_MarketShouldNotHoldTokens() public {
        assertEq(
            paymentToken.balanceOf(address(market)),
            0,
            "Market should not hold any tokens"
        );
    }
}