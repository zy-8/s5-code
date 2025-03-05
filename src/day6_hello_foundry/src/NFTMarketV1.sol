// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketV1 is EIP712("NFTMarket", "1.0"), ReentrancyGuard, Ownable {

    // 卖家签名类型哈希
    bytes32 public constant SELL_TYPEHASH =
    keccak256("Sell(address nftContract,uint256 tokenId,uint256 price,address paymentToken,uint256 nonce,uint256 deadline)");

    address public constant ETH_ADDRESS = address(0);

    // 卖家nonce
    mapping(address => uint256) public nonces;


    // 订单执行事件
    event OrderExecuted(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint256 price);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT tokenId
     * @param paymentToken 支付代币地址
     * @param price 价格
     * @param nonce 订单编号
     * @param deadline 签名过期时间
     * @param signature 卖家签名
     */
    function orderExecuted(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external payable nonReentrant{
        // 验证签名过期时间
        require(deadline > block.timestamp, "Order expired");
        // 验证签名
        bytes32 structHash = keccak256(abi.encode(SELL_TYPEHASH, nftContract, tokenId, price, paymentToken,nonce, deadline));
        // 计算哈希值
        bytes32 hash = _hashTypedDataV4(structHash);
        // 获取签名者
        address seller = ECDSA.recover(hash, signature);
        // 验证卖家nonce
        require(nonce == nonces[seller]++, "Invalid nonce");
        //获取NFT当前所有者
        address currentOwner = IERC721(nftContract).ownerOf(tokenId);
        //验证签名者是否为卖家
        require(seller == currentOwner, "Invalid signature");

        //支付处理
        if (paymentToken == ETH_ADDRESS) {
            //ETH支付
            require(msg.value == price, "Invalid payment");
            //转移ETH给卖家
            (bool success,) = payable(seller).call{value: price}("");
            require(success, "Transfer failed");
        } else {
            //ERC20支付
            SafeERC20.safeTransferFrom(IERC20(paymentToken), msg.sender, currentOwner, price);
        }
        //执行购买
        IERC721(nftContract).safeTransferFrom(currentOwner, msg.sender, tokenId);
        //成功后触发事件
        emit OrderExecuted(structHash, msg.sender, seller, price);
    }
}
