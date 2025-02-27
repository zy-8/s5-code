// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTMarket712 is EIP712 {
    // EIP712 类型哈希
    bytes32 public constant WHITELIST_TYPEHASH =
        keccak256("WhitelistPermit(address buyer,uint256 nonce)");

    IERC20 public immutable paymentToken;
    IERC20Permit public immutable tokenPermit;
    address public immutable owner;

    // 防止重放攻击
    mapping(address => uint256) public nonces;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    // NFT合约地址 => NFT ID => 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 添加重入保护状态变量
    bool private locked;

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

    // 添加重入保护修饰器
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        address _paymentToken
    )
        EIP712("NFTMarket", "1.0") // EIP712 构造函数参数
    {
        require(_paymentToken != address(0), "Invalid payment token");
        paymentToken = IERC20(_paymentToken);
        tokenPermit = IERC20Permit(_paymentToken);
        owner = msg.sender;
    }

    function list(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant {
        require(price > 0, "Price must be greater than 0");
        require(nftContract != address(0), "Invalid NFT contract");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        require(
            nft.getApproved(tokenId) == address(this) ||
                nft.isApprovedForAll(msg.sender, address(this)),
            "NFT not approved"
        );

        nft.transferFrom(msg.sender, address(this), tokenId);

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            isActive: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    function permitBuy(
        address nftContract,
        uint256 tokenId,
        bytes calldata signature // 项目方的白名单签名
    ) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT not listed");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        // 验证白名单签名 - 使用 EIP712
        bytes32 structHash = keccak256(
            abi.encode(WHITELIST_TYPEHASH, msg.sender, nonces[msg.sender])
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(signer == owner, "Invalid whitelist signature");

        // 更新 nonce 防止重放
        nonces[msg.sender]++;

        // 执行支付和转移
        require(
            paymentToken.transferFrom(
                msg.sender,
                listing.seller,
                listing.price
            ),
            "Payment failed"
        );

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        delete listings[nftContract][tokenId];
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.price);
    }

    function getListing(
        address nftContract,
        uint256 tokenId
    ) external view returns (address seller, uint256 price, bool isActive) {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }
}
