pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
/**
 * 实现一个 AirdopMerkleNFTMarket 合约(假定 Token、NFT、AirdopMerkleNFTMarket 都是同一个开发者开发)，功能如下：
 *
 *     基于 Merkel 树验证某用户是否在白名单中
 *     在白名单中的用户可以优惠 50% 的Token 来购买 NFT， Token 需支持 permit 授权。
 *     要求使用 multicall( delegateCall 方式) 一次性调用两个方法：
 *
 *     permitPrePay() : 调用token的 permit 进行授权
 *     claimNFT() : 通过默克尔树验证白名单，并利用 permitPrePay 的授权，转入 token 转出 NFT
 */
contract AirdopMerkleNFT is ERC721("AirdopMerkleNFT", "AMNFT") {
    //root hash
    bytes32 public immutable rootHash;
    //base price
    uint256 public immutable basePrice;
    address public immutable payToken;


    constructor(bytes32 _rootHash, uint256 _basePrice, address _payToken) {
        rootHash = _rootHash;
        basePrice = _basePrice;
        payToken = _payToken;
    }

    /**
     * @dev 调用token的 permit 进行授权
     * @param token 代币地址
     * @param amount 授权数量
     * @param deadline 授权截止时间
     * @param v 签名v
     * @param r 签名r
     * @param s 签名s
     */
    function permitPrePay(address token, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        // 调用token的 permit 进行授权
        IERC20Permit(token).permit(msg.sender, address(this), amount, deadline, v, r, s);
    }

    /**
     * @dev 通过默克尔树验证白名单
     * @param proof 默克尔树证明
     */
    function claimNFT(bytes32[] calldata proof) public {
        // 通过默克尔树验证白名单
        bool isWhitelisted = MerkleProof.verify(proof, rootHash, keccak256(abi.encodePacked(msg.sender)));
        // 转出token
        SafeERC20.safeTransferFrom(IERC20(payToken), msg.sender, address(this), isWhitelisted ? basePrice * 50 / 100 : basePrice);
        //转出nft
        _mint(msg.sender, 1);
    }

    /**
     * @dev 一次性调用两个方法
     * @param data 方法数据
     */
    function multicall(bytes[] calldata data) public {
        require(data.length > 0, "Invalid data length");
        for (uint256 i = 0; i < data.length; i++) {
            (bool success,) = address(this).delegatecall(data[i]);
            require(success, "Delegate call failed");
        }
    }
}
