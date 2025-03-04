// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPermit2.sol";

contract TokenBankPermit2 {
    IPermit2 public permit2;

    // 记录用户存款
    // token => user => amount
    mapping(address => mapping(address => uint256)) public balances;

    // 事件
    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);

    constructor(address _permit2) {
        require(_permit2 != address(0), "Token address cannot be zero");
        permit2 = IPermit2(_permit2);
    }

    /**
     * @notice 存入代币
     * @param token 代币地址
     * @param amount 存入数量
     * @param nonce 防重放 nonce
     * @param deadline 签名截止时间
     * @param signature 签名数据
     */
    function depositWithPermit2(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        // 更新用户余额
        balances[token][msg.sender] += amount;
        permit2.permitTransferFrom(
        //单个令牌传输的已签名许可消息
            ISignatureTransfer.PermitTransferFrom({
            // 在许可转让签名中签署的转让令牌和金额详细信息
                permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: amount}),
            // 每个令牌所有者的唯一值，以防止签名重放
                nonce: nonce,
            // 许可证签字的截止日期
                deadline: deadline
            }),
            // transferDetails发送者请求的允许令牌的传输详细信息
            ISignatureTransfer.SignatureTransferDetails({
            // 设置接收者地址
                to: address(this),
            // 设置请求的金额
                requestedAmount: amount
            }),
            // 设置发送者地址
            msg.sender,
            // 要验证的签名
            signature
        );
        emit Deposit(token, msg.sender, amount);
    }

    /**
     * @notice 提取代币
     * @param token 代币地址
     * @param amount 提取数量
     */
    function withdraw(address token, uint256 amount) external {
        require(balances[token][msg.sender] >= amount, "Insufficient balance");
        // 先更新状态，防止重入攻击
        balances[token][msg.sender] -= amount;
        // 转移代币给用户
        SafeERC20.safeTransfer(IERC20(token), msg.sender, amount);
        emit Withdraw(token, msg.sender, amount);
    }
}
