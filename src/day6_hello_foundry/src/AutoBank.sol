// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AutoBank is AutomationCompatibleInterface, Ownable {

  address public receiver;
  uint256 public threshold;

  mapping(address => uint256) public balanceOf;

  event Deposit(address indexed user, uint256 amount);
  event Withdrawal(address indexed user, uint256 amount);
  event AutoTransfer(uint256 amount, address indexed receiver);

  constructor(address _receiver, uint256 _threshold) Ownable(msg.sender) {
    require(_receiver != address(0), "Receiver address cannot be zero");
    require(_threshold != 0, "Threshold cannot be zero");
    receiver = _receiver;
    threshold = _threshold;
  }

  function setReceiver(address _receiver) external onlyOwner {
    require(_receiver != address(0), "Receiver address cannot be zero");
    receiver = _receiver;
  }

  function setThreshold(uint256 _threshold) external onlyOwner {
    require(_threshold != 0, "Threshold cannot be zero");
    threshold = _threshold;
  }

  function depositETH() external payable {
    require(msg.value > 0, "Deposit amount must be greater than 0");
    balanceOf[msg.sender] += msg.value;
    emit Deposit(msg.sender, msg.value);
  }

  /**
   * @notice 检查是否需要执行自动转账
   * @return upkeepNeeded 是否需要执行
   * @return performData 执行数据
   */
  function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
    uint256 balance = address(this).balance;
    upkeepNeeded = balance >= threshold;
    if (upkeepNeeded) {
      uint256 transferValue = balance / 2;
      performData = abi.encode(transferValue);
    }
  }

  /**
   * @notice 执行自动转账
   * @param performData 包含转账金额的数据
   */
  function performUpkeep(bytes calldata performData) external override {
    (uint256 transferValue) = abi.decode(performData, (uint256));
    (bool success,) = payable(receiver).call{ value: transferValue }("");
    require(success, "ETH transfer failed");
    emit AutoTransfer(transferValue, receiver);
  }
}
