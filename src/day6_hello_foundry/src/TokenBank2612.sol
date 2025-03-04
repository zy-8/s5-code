// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract TokenBank2612  {

    IERC20 public immutable token;
    IERC20Permit public immutable tokenPermit;

    // 记录用户存款
    mapping(address => uint256) public balances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PermitDeposit(address indexed user, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s);

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
        tokenPermit = IERC20Permit(_token);
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

        SafeERC20.safeTransfer(token, msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice 支持离线签名授权(permit)进行存款。
     * @param amount 存入数量
     * @param owner 授权人
     * @param deadline 过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitDeposit(uint256 amount, address owner, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        tokenPermit.permit(owner, address(this), amount, deadline, v, r, s);
        SafeERC20.safeTransferFrom(token, owner, address(this), amount);
        balances[owner] += amount;
        emit PermitDeposit(owner, amount, deadline, v, r, s);
    }

}