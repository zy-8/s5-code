// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultipleContracts {
    //定义事件
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event RevokeTransaction(
        address indexed owner,
        uint256 indexed transactionIndex
    );
    event ConfirmTransaction(
        address indexed owner,
        uint256 indexed transactionIndex
    );
    event ExecuteTransaction(
        address indexed owner,
        uint256 indexed transactionIndex
    );
    //多签持有人地址数组
    address[] public owners;
    //地址是否为多签持有人的映射
    mapping(address => bool) public isOwner;
    //签名门槛
    uint256 public numConfirmationsRequired;
    //交易结构体
    struct Transaction {
        address to; //交易目标地址
        uint256 value; //交易金额
        bytes data; //交易数据
        bool executed; //交易是否已执行
        uint256 numConfirmations; //交易确认数
    }
    // 所有交易数组
    Transaction[] public transactions;
    // 交易确认状态映射 (交易索引 => 所有者地址 => 是否确认)
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // 只允许多签持有人调用
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    //交易必须存在
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }
    //交易必须未执行
    modifier notExecuted(uint256 _txIndex) {
        require(
            !transactions[_txIndex].executed,
            "Transaction already executed"
        );
        _;
    }
    //交易未被当前调用者调用
    modifier notConfirmed(uint256 _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "Transaction already confirmed"
        );
        _;
    }

    /**
     * @dev 构造函数
     * @param _owners 多签持有人地址数组
     * @param _numConfirmationsRequired 签名门槛
     */
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners array is empty");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "Invalid number of required confirmations"
        );
        //初始化多签持有人地址数组
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner address");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /**
     * @dev 提交交易提案
     * @param _to 目标地址
     * @param _value 转账金额
     * @param _data 调用数据
     */
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        //交易索引
        uint256 txIndex = transactions.length;
        //添加交易
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );
        //触发提案事件
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /**
     * @dev 确认交易
     * @param _txIndex 交易索引
     * @notice 交易必须存在，未被执行，且当前调用者为多签持有人
     */
    function confirmTransaction(
        uint256 _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex){
        Transaction storage transaction = transactions[_txIndex];
        //确认人数+1
        transaction.numConfirmations += 1;
        //设置确认状态
        isConfirmed[_txIndex][msg.sender] = true;
        //触发确认事件
        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev 撤销交易
     * @param _txIndex 交易索引
     * @notice 交易必须存在，未被执行，且当前调用者为多签持有人
     */
    function revokeTransaction(
        uint256 _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex){
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;
        emit RevokeTransaction(msg.sender, _txIndex);
    }

    /** 
     * @dev 执行交易
     * @param _txIndex 交易索引
     * @notice 交易必须存在，未被执行，且当前调用者为多签持有人
     */
    function executeTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );
        //设置交易执行状态
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");
        //触发执行事件
        emit ExecuteTransaction(msg.sender, _txIndex);
    }
        

    /**
     * @dev 获取多签持有人地址数组
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev 获取交易数量
     */
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    /**
     * @dev 获取交易详情
     */
    function getTransactionCount(
        uint256 _txIndex
    )
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    // 接收ETH
    receive() external payable {}
}
