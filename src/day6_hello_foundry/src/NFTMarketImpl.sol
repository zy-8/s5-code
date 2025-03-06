// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract NFTMarketImpl is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // 支付代币
    IERC20 public paymentToken;

    // NFT上架信息结构
    struct Listing {
        address seller;    // 卖家地址
        uint256 price;    // 价格
        bool isActive;    // 是否在售
    }

    // NFT合约地址 => NFT ID => 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 上架事件
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    // 购买事件
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);

    // 禁用初始化
    constructor() {
        _disableInitializers();
    }

    // 初始化函数
    function initialize(address _paymentToken) public initializer {
        require(_paymentToken != address(0), "Invalid payment token");
        __Ownable_init(msg.sender);
        paymentToken = IERC20(_paymentToken);
    }

    // 升级授权
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @notice NFT上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT ID
     * @param price 价格
     */
    function list(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "Price must be greater than 0");
        require(nftContract != address(0), "Invalid NFT contract");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "NFT not approved"
        );

        nft.transferFrom(msg.sender, address(this), tokenId);

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    /**
     * @notice 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT ID
     */
    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT not listed");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        paymentToken.safeTransferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.price);
    }

    /**
     * @notice 获取NFT上架信息
     * @param nftContract NFT合约地址
     * @param tokenId NFT ID
     */
    function getListing(address nftContract, uint256 tokenId)
    external
    view
    returns (address seller, uint256 price, bool isActive)
    {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }
}
