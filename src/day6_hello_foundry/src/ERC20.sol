// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20.sol";

interface ITokenReceiver {
    function tokensReceived(address sender, uint256 amount) external;
}

contract ERC20 is IERC20 {
    //名称
    string public name;
    //符号
    string public symbol;
    //小数位
    uint8 public decimals = 18;
    //总量
    uint256 public totalSupply;
    //地址对应的余额
    mapping(address => uint256) public balances;
    //授权信息（地址允许另一个地址花费多少 Token）
    mapping(address => mapping(address => uint256)) public allowances;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        // 设置总量为合约部署者的初始余额
        balances[msg.sender] = totalSupply;
    }

    //查询账户余额
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    //转移代币
    function transfer(address recipient, uint256 amount) external returns (bool) {
        //判断转账金额是否大于转出金额
        require(balances[msg.sender] >= amount,"ERC20: transfer amount exceeds balance");
        //开始转账操作
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    //查询授权余额
    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    //授权
    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    /**
        sender 代币持有者
        recipient 接收者地址
        amount 转出金额
    **/
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        // 检查调用者是否有被授权余额
        require(allowances[sender][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        // 检查当前余额是否大于或等于转出金额
        require(balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        // 执行余额变动
        balances[sender] -= amount;
        balances[recipient] += amount;
        // 更新授权余额
        allowances[sender][msg.sender] -= amount;
        // 触发 Transfer 事件
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @notice 代币转账时带回调
     * @param recipient 收款地址
     * @param amount 转账金额
     */
    function transferWithCallback(address recipient, uint256 amount) external {
        require(balances[msg.sender] >= amount, "ERC20: transfermsg.sender >= amount");
        //开始转账操作
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        //记录log
        emit Transfer(msg.sender, recipient, amount);
        // 如果目标地址是合约地址，调用tokensReceived方法
        if (isContract(recipient)) {
            ITokenReceiver(recipient).tokensReceived(msg.sender, amount);
        }
    }

    /**
     * @notice 判断目标地址是否为合约地址
     * @param account 地址
     * @return bool
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // extcodesize 返回合约代码大小，如果为0，表示目标地址不是合约
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
