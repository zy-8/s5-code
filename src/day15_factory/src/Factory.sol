// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";


// 代币实现合约
contract TokenImpl is ERC20 {
    // 工厂地址
    address public factory;
    // 代号
    string private _tokenSymbol;
    // 是否初始化
    bool private initialized;

    constructor() ERC20("","") {}

    function initialize(string memory symbol_, address factory_) external {
        require(!initialized, "Already initialized");
        require(factory_ != address(0), "Invalid factory");
        factory = factory_;
        _tokenSymbol = symbol_;
        initialized = true;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == factory, "Only factory can mint");
        _mint(to, amount);
    }

    function symbol() public view virtual override returns (string memory) {
        return _tokenSymbol;
    }
}


contract Factory {
    // 克隆库
    using Clones for address;

    // 手续费 10%
    uint256 public constant FEE_PERCENTAGE = 10;
    struct TokenInfo {
        string symbol; // 代号
        uint256 totalSupply; // 总发行量
        uint256 perMint; // 单次铸造数量
        uint256 price; // 代币铸造时需要的费用（wei 计价）
    }
    // 铸造信息 代币地址 => 铸造信息
    mapping(address => TokenInfo) public tokenToTokenInfo;
    // 铸造数量 代币地址 => 铸造数量
    mapping(address => uint256) public tokenToMint;
    // 发行者 代币地址 => 发行者
    mapping(address => address) public tokenToCreator;
    // 代币实现合约地址
    address public tokenImpl;
    // 代币实现合约所有者
    address public owner;

    // 部署事件
    event TokenCreated(address indexed tokenAddr, address indexed creator, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    // 铸造事件
    event TokenMinted(address indexed tokenAddr, address indexed creator, uint256 amount);

    constructor(address _tokenImpl) {
        tokenImpl = _tokenImpl;
        owner = msg.sender;
    }

    // ⽤户调⽤该⽅法创建 ERC20 Token合约，
    function deployToken(TokenInfo memory tokenInfo) public returns (address) {
        // 检查铸造数量是否大于0
        require(tokenInfo.totalSupply > 0, "Total supply is not enough");
        // 检查铸造数量是否大于0
        require(tokenInfo.perMint > 0, "Per mint is not enough");
        // 检查铸造数量是否大于0
        require(tokenInfo.price > 0, "Price is not enough");

        // 使用最小代理克隆合约
        address clone = tokenImpl.clone();

        // 初始化代币实现合约，传入 factory 地址
        TokenImpl(clone).initialize(tokenInfo.symbol, address(this));

        // 将合约地址和铸造信息存储到 mapping 中
        tokenToTokenInfo[clone] = tokenInfo;
        // 将合约地址和发行者存储到 mapping 中
        tokenToCreator[clone] = msg.sender;

        // 触发部署事件
        emit TokenCreated(clone, msg.sender, tokenInfo.symbol, tokenInfo.totalSupply, tokenInfo.perMint, tokenInfo.price);

        return clone;
    }

    //每次调用发行创建时确定的 perMint 数量的 token，并收取相应的费用
    function mintToken(address tokenAddr) payable public {
        //获取铸造信息
        TokenInfo memory tokenInfo = tokenToTokenInfo[tokenAddr];
        //检查手续费是否大于代币铸造时需要的费用
        require(msg.value >= tokenInfo.price, "Price is not enough");
        //检查铸造数量是否小于或等于总发行量
        require(tokenToMint[tokenAddr] + tokenInfo.perMint <= tokenInfo.totalSupply, "Total supply is not enough");
        // 分配10%手续费给项目方
        uint256 platformFee = tokenInfo.price * FEE_PERCENTAGE / 100;
        // 分配90%手续费给发行者
        uint256 userFee = tokenInfo.price - platformFee;

        // 将手续费分配给项目方
        (bool success1,) = owner.call{value: platformFee}("");
        require(success1, "Platform fee transfer failed");

        // 将手续费分配给发行者
        (bool success2,) = tokenToCreator[tokenAddr].call{value: userFee}("");
        require(success2, "Creator fee transfer failed");

        // 铸造 token
        TokenImpl(tokenAddr).mint(msg.sender, tokenInfo.perMint);
        // 铸造总数量 + 当前铸造数量
        tokenToMint[tokenAddr] += tokenInfo.perMint;

        // 触发铸造事件
        emit TokenMinted(tokenAddr, msg.sender, tokenInfo.perMint);
    }
}