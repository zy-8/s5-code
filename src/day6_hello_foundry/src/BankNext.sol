// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Bank Contract with Ranked List
 * @notice 使用单向链表实现的排名系统
 * 
 * 数据结构:
 * - balanceOf: 存储用户余额
 * - rank: 链表关系映射，key是当前地址，value是下一个地址
 * - GUARD: 哨兵节点，使用address(1)，用于简化边界条件处理
 * 
 * 链表示例:
 * GUARD -> C(150) -> A(100) -> B(80) -> D(60) -> GUARD
 *   ^                                              |
 *   |______________________________________________|
 */
contract BankNext {
    // 用户余额
    mapping(address => uint) public balanceOf;
    // 链表关系: current address => next address
    mapping(address => address) public rank;
    // 链表大小
    uint256 public listSize;
    // 哨兵节点，用作链表头尾
    address constant GUARD = address(1);
    
    event Deposit(address indexed user, uint amount);

    /**
     * @dev 初始化合约，设置哨兵节点
     * 初始状态: GUARD -> GUARD（空链表）
     */
    constructor() {
        rank[GUARD] = GUARD;
    }

    /**
     * @notice 用户存款函数
     * @dev 存款后更新用户余额和排名
     * 
     * 示例流程:
     * 1. 用户A存100: GUARD -> A(100) -> GUARD
     * 2. 用户B存80:  GUARD -> A(100) -> B(80) -> GUARD
     * 3. 用户C存150: GUARD -> C(150) -> A(100) -> B(80) -> GUARD
     */
    function depositETH() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        uint oldBalance = balanceOf[msg.sender];
        balanceOf[msg.sender] += msg.value;
        
        if (oldBalance == 0) {
            insertNew(msg.sender);
        } else {
            updatePosition(msg.sender);
        }
        
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 插入新用户到链表中
     * @param user 新用户地址
     * 
     * 插入步骤:
     * 1. 从GUARD开始遍历
     * 2. 找到第一个余额小于新用户的位置
     * 3. 插入新节点
     * 
     * 示例: 插入用户C(150)
     * 之前: GUARD -> A(100) -> B(80) -> GUARD
     * 之后: GUARD -> C(150) -> A(100) -> B(80) -> GUARD
     */
    function insertNew(address user) internal {
        require(rank[user] == address(0), "User already exists");
        
        address candidate = GUARD;
        while (rank[candidate] != GUARD) {
            if (balanceOf[rank[candidate]] < balanceOf[user]) {
                break;
            }
            candidate = rank[candidate];
        }
        
        rank[user] = rank[candidate];
        rank[candidate] = user;
        listSize++;
    }

    /**
     * @dev 更新用户在链表中的位置
     * @param user 用户地址
     * 
     * 更新步骤:
     * 1. 找到用户的前一个节点
     * 2. 验证是否需要移动
     * 3. 如需移动：移除并重新插入
     * 
     * 示例: 用户B增加余额至180
     * 之前: GUARD -> C(150) -> A(100) -> B(80) -> D(60) -> GUARD
     * 移除: GUARD -> C(150) -> A(100) -> D(60) -> GUARD
     * 之后: GUARD -> B(180) -> C(150) -> A(100) -> D(60) -> GUARD
     */
    function updatePosition(address user) internal {
        require(rank[user] != address(0), "User not found");
        
        address prevUser = findPrevious(user);
        if (prevUser == address(0)) return;
        
        if (_verifyPosition(prevUser, balanceOf[user], rank[user])) {
            return; // 位置正确，不需要移动
        }
        
        // 移除节点
        rank[prevUser] = rank[user];
        rank[user] = address(0);
        listSize--;
        
        // 重新插入
        insertNew(user);
    }

    /**
     * @dev 找到指定地址的前一个节点
     * @param user 目标用户地址
     * @return 前一个节点地址
     * 
     * 遍历步骤:
     * 1. 从GUARD开始遍历
     * 2. 找到指向目标用户的节点
     * 
     * 示例: 找用户B的前一个节点
     * GUARD -> C -> A -> B -> D -> GUARD
     * 返回: A
     */
    function findPrevious(address user) internal view returns (address) {
        address current = GUARD;
        while (rank[current] != GUARD) {
            if (rank[current] == user) {
                return current;
            }
            current = rank[current];
        }
        return address(0);
    }

    /**
     * @dev 验证节点位置是否正确
     * @param prevUser 前一个用户
     * @param value 当前用户余额
     * @param nextUser 后一个用户
     * @return 位置是否正确
     * 
     * 验证规则:
     * 1. 前一个节点是GUARD 或 前节点余额 >= 当前余额
     * 2. 后一个节点是GUARD 或 当前余额 > 后节点余额
     */
    function _verifyPosition(
        address prevUser, 
        uint256 value, 
        address nextUser
    ) internal view returns (bool) {
        return (prevUser == GUARD || balanceOf[prevUser] >= value) && 
               (nextUser == GUARD || value > balanceOf[nextUser]);
    }

    /**
     * @notice 获取排名前N的用户
     * @param n 要获取的用户数量
     * @return users 用户地址数组
     * @return balances 对应的余额数组
     * 
     * 示例:
     * 链表: GUARD -> B(180) -> C(150) -> A(100) -> D(60) -> GUARD
     * getTopUsers(3) 返回: 
     * users = [B, C, A]
     * balances = [180, 150, 100]
     */
    function getTopUsers(uint256 n) external view returns (address[] memory, uint[] memory) {
        require(n > 0 && n <= listSize, "Invalid number of users");
        
        address[] memory users = new address[](n);
        uint[] memory balances = new uint[](n);
        
        address current = rank[GUARD];
        for (uint256 i = 0; i < n; i++) {
            users[i] = current;
            balances[i] = balanceOf[current];
            current = rank[current];
        }
        
        return (users, balances);
    }

    /**
     * @notice 获取用户排名
     * @param user 用户地址
     * @return 用户排名（从1开始）
     * 
     * 示例:
     * 链表: GUARD -> B(180) -> C(150) -> A(100) -> D(60) -> GUARD
     * getUserRank(A) 返回: 3
     */
    function getUserRank(address user) external view returns (uint) {
        require(rank[user] != address(0), "User not found");
        
        uint256 position = 1;
        address current = rank[GUARD];
        
        while (current != GUARD) {
            if (current == user) {
                return position;
            }
            position++;
            current = rank[current];
        }
        
        revert("User not found in ranking");
    }
}