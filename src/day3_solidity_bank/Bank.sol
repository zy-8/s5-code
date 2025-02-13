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

    function updateTopUser(address user, uint256 amount) private {
        // 遍历前三名存款用户
        for (uint256 i = 0; i < 3; i++) {
            User storage currentUser = topUser[i]; // 获取当前存款用户信息

            // 如果当前用户未初始化或存款金额大于当前用户
            if (
                currentUser.userAddr == address(0) ||
                amount > currentUser.balance
            ) {
                // 右移数组，避免覆盖原有数据
                for (uint256 j = 2; j > i; j--) {
                    topUser[j] = topUser[j - 1]; // 右移
                }
                // 插入新用户
                topUser[i] = User(user, amount);
                break;
            }
        }
    }

    // 获取前三名存款用户
    function getTopUsers() public view returns (User[3] memory) {
        return topUser;
    }
}
