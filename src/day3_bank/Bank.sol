// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    
    struct User {
        address userAddr;
        uint256 balance;
    }

    //管理员
    address internal admin;
    //存款用户-金额
    mapping(address => uint256) public balanceOf;
    //存款前三用户
    User[3] internal topUser;

    // constructor(address _admin){
    //     admin = _admin;
    // }

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balanceOf[msg.sender] += msg.value;
        updateTopUser(msg.sender, balanceOf[msg.sender]);
    }

    fallback() external payable {}

    //记录每个地址的存款金额
    // function deposit() public payable {
    //     require(msg.value > 0, "Deposit amount must be greater than 0");
    //     deposits[msg.sender] += msg.value;
    //     updateTopUser(msg.sender, deposits[msg.sender]);
    // }

    //从合约取款
    function withdraw(uint256 value) public {
        //判断调用者是指定的管理员
        require(msg.sender == admin, "Unauthorized");
        //判断合约中是否有足够的eth
        require(
            address(this).balance >= value,
            "Contract has insufficient balance"
        );
        payable(msg.sender).transfer(value);
    }

    function updateTopUser(address user, uint256 amount) internal {
        // 如果金额为0，直接返回
        if (amount == 0) return;

        // 记录用户当前位置和应插入的位置
        uint256 currentPos = 3;
        uint256 insertPos = 3;

        // 查找用户当前位置和合适的插入位置
        for (uint256 i = 0; i < 3; i++) {
            if (topUser[i].userAddr == user) {
                currentPos = i;
            }
            if (
                insertPos == 3 &&
                (topUser[i].userAddr == address(0) ||
                    amount > topUser[i].balance)
            ) {
                insertPos = i;
            }
        }

        // 如果用户不在前三且金额不足以进入前三，直接返回
        if (currentPos == 3 && insertPos == 3) return;

        // 如果用户已在列表中
        if (currentPos < 3) {
            // 如果新金额小于等于当前金额且位置更靠前，无需更新
            if (
                amount <= topUser[currentPos].balance && currentPos <= insertPos
            ) return;

            // 移除当前用户
            for (uint256 i = currentPos; i < 2; i++) {
                topUser[i] = topUser[i + 1];
            }
            topUser[2] = IBank.User(address(0), 0);

            // 重新计算插入位置
            insertPos = 2;
            for (uint256 i = 0; i < 3; i++) {
                if (
                    topUser[i].userAddr == address(0) ||
                    amount > topUser[i].balance
                ) {
                    insertPos = i;
                    break;
                }
            }
        }

        // 插入新记录
        if (insertPos < 3) {
            // 移动元素
            for (uint256 i = 2; i > insertPos; i--) {
                topUser[i] = topUser[i - 1];
            }
            // 插入新记录
            topUser[insertPos] = IBank.User(user, amount);
        }
    }

    // 获取前三名存款用户
    function getTopUsers() public view returns (User[3] memory) {
        return topUser;
    }
}
