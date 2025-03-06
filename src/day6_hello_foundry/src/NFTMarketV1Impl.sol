// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NFTMarketV1Impl is
Initializable,
ReentrancyGuardUpgradeable,
OwnableUpgradeable,
UUPSUpgradeable,
EIP712Upgradeable
{
    using SafeERC20 for IERC20;

    // 保持与V1版本相同的存储布局
    IERC20 public paymentToken;

    // NFT上架信息结构
    struct Listing {
        address seller; // 卖家地址
        uint256 price; // 价格
        bool isActive; // 是否在售
    }

    // NFT合约地址 => NFT ID => 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // V2新增：签名订单状态
    mapping(bytes32 => bool) public orderExecuted;

    // V2新增：签名类型哈希
    bytes32 public constant SELL_TYPEHASH = keccak256(
        "Sell(address nftContract,uint256 tokenId,uint256 price,address paymentToken,uint256 nonce,uint256 deadline)"
    );

    // V2新增：ETH支付地址常量
    address public constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    // 事件定义
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);
    event OrderExecuted(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint256 price);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _paymentToken) public reinitializer(2) {
        require(_paymentToken != address(0), "Invalid payment token");
        __EIP712_init("NFTMarket", "2.0");
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        paymentToken = IERC20(_paymentToken);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // 保留V1的常规上架功能
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

        listings[nftContract][tokenId] = Listing({seller: msg.sender, price: price, isActive: true});

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    // 保留V1的常规购买功能
    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT not listed");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        paymentToken.safeTransferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.price);
    }

    // V2新增：签名购买功能
    /**
     * @notice 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT tokenId
     * @param price 价格
     * @param payToken 支付代币地址
     * @param nonce 随机数
     * @param deadline 签名过期时间
     * @param signature 卖家签名
     */
    function executeOrder(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address payToken,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external payable nonReentrant {
        // 生成订单ID
        bytes32 orderId = keccak256(abi.encode(nftContract, tokenId, price, payToken, nonce, deadline, signature));

        // 检查订单是否已执行
        require(!orderExecuted[orderId], "Order already executed");

        // 验证签名过期时间
        require(deadline > block.timestamp, "Order expired");
        // 验证签名
        bytes32 structHash =
                        keccak256(abi.encode(SELL_TYPEHASH, nftContract, tokenId, price, payToken, nonce, deadline));
        // 计算哈希值
        bytes32 hash = _hashTypedDataV4(structHash);
        // 获取签名者
        address seller = ECDSA.recover(hash, signature);
        //获取NFT当前所有者
        address currentOwner = IERC721(nftContract).ownerOf(tokenId);
        //验证签名者是否为卖家
        require(seller == currentOwner, "Invalid signature");

        // 标记订单已执行
        orderExecuted[orderId] = true;

        //支付处理
        if (payToken == ETH_ADDRESS) {
            //ETH支付
            require(msg.value == price, "Invalid payment");
            //转移ETH给卖家
            (bool success,) = payable(seller).call{value: price}("");
            require(success, "Transfer failed");
        } else {
            //ERC20支付
            SafeERC20.safeTransferFrom(IERC20(payToken), msg.sender, currentOwner, price);
        }
        //执行购买
        IERC721(nftContract).safeTransferFrom(currentOwner, msg.sender, tokenId);
        //成功后触发事件
        emit OrderExecuted(orderId, msg.sender, seller, price);
    }

    // 查询NFT上架信息
    function getListing(address nftContract, uint256 tokenId)
    external
    view
    returns (address seller, uint256 price, bool isActive)
    {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }
}
