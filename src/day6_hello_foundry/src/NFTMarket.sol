// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenReceiver {
    function tokensReceived(
        address from, // 买家地址
        uint256 amount, // 支付金额
        bytes calldata data // 购买信息 nftContract,tokenId
    ) external returns (bool);
}

contract NFTMarket is ITokenReceiver {
    IERC20 public immutable paymentToken;
    
    // 添加重入保护状态变量
    bool private locked;
    
    // 添加重入保护修饰器
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    // NFT合约地址 => NFT ID => 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

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

    constructor(address _paymentToken) {
        require(_paymentToken != address(0), "Invalid payment token");
        paymentToken = IERC20(_paymentToken);
    }

    function list(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant {
        //判断价格 > 0
        require(price > 0, "Price must be greater than 0");
        //nft地址不能为0
        require(nftContract != address(0), "Invalid NFT contract");

        IERC721 nft = IERC721(nftContract);
        //查询是否为tokenId持有者
        require(nft.ownerOf(tokenId) == msg.sender, "Not the NFT owner");

        // 检查是否已经授权给市场合约
        require(
            nft.getApproved(tokenId) == address(this) ||
            nft.isApprovedForAll(msg.sender, address(this)),
            "NFT not approved"
        );

        // 转移NFT到市场合约
        nft.transferFrom(msg.sender, address(this), tokenId);

        // 创建上架信息
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            isActive: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    function buyNFT(address nftContract, uint256 tokenId)
    external
    nonReentrant
    {
        //获取listing信息
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT not listed");
        //防止自己购买自己的nft
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        // 处理支付
        require(
            paymentToken.transferFrom(
                msg.sender,
                listing.seller,
                listing.price
            ),
            "Payment failed"
        );

        // 转移NFT
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // 清除上架信息
        delete listings[nftContract][tokenId];

        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.price);
    }

    function tokensReceived(
        address from, // 买家地址
        uint256 amount, // 支付金额
        bytes calldata data // 购买信息 nftContract,tokenId
    ) external override returns (bool) {
        //
        require(msg.sender == address(paymentToken), "Invalid token");

        // 解码购买信息
        (address nftContract, uint256 tokenId) = abi.decode(
            data,
            (address, uint256)
        );

        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");
        require(from != listing.seller, "Cannot buy your own NFT");

        // 转移支付给卖家
        require(
            paymentToken.transfer(listing.seller, listing.price),
            "Payment transfer failed"
        );

        // 处理多余的支付
        if (amount > listing.price) {
            require(
                paymentToken.transfer(from, amount - listing.price),
                "Refund failed"
            );
        }

        // 转移NFT给买家
        IERC721(nftContract).transferFrom(address(this), from, tokenId);

        // 清除上架信息
        delete listings[nftContract][tokenId];

        emit NFTPurchased(nftContract, tokenId, from, listing.price);

        return true;
    }

    // 查询上架信息
    function getListing(address nftContract, uint256 tokenId)
    external
    view
    returns (
        address seller,
        uint256 price,
        bool isActive
    )
    {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }
}
