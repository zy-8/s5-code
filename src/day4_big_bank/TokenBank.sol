// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenBank is ReentrancyGuard {
    IERC20 public token;

    // 记录用户存款
    mapping(address => uint256) public balances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    /**
     * @notice 存入代币
     * @param amount 存入数量
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");

        // 检查用户是否授权足够的代币
        require(token.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance");

        // 转移代币到合约
        require(token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed");

        // 更新用户余额
        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice 提取代币
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // 先更新状态，防止重入攻击
        balances[msg.sender] -= amount;

        // 转移代币给用户
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice 查询用户在银行中的代币余额
     * @param user 用户地址
     */
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    /**
     * @notice 查询合约中的代币总量
     */
    function totalTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}