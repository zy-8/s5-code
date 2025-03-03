// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPermit2.sol";

contract TokenBankPermit2 {
    IPermit2 public permit2;

    // 记录用户存款
    mapping(address => uint256) public balances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _permit2) {
        require(_permit2 != address(0), "Token address cannot be zero");
        permit2 = IPermit2(_permit2);
    }

    /**
     * @notice 存入代币
     * @param amount 存入数量
     */
    function depositWithPermit2(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(amount > 0, "Amount must be greater than 0");
        // 更新用户余额
        balances[msg.sender] += amount;
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
        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice 提取代币
     * @param amount 提取数量
     */
    function withdraw(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // 先更新状态，防止重入攻击
        balances[msg.sender] -= amount;

        // 转移代币给用户
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }
}
