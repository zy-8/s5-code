// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract TokenBank  {
    IERC20 public token;

    // 记录用户存款
    mapping(address => uint256) public balances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _token){
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    /**
     * @notice 存入代币
     * @param amount 存入数量
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // 检查用户是否授权足够的代币
        require(token.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance");

        // 转移代币到合约
        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);

        // 更新用户余额
        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice 提取代币
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // 先更新状态，防止重入攻击
        balances[msg.sender] -= amount;
        // 转移代币给用户
        SafeERC20.safeTransfer(token, msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

}