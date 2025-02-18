// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Azuki is ERC721URIStorage {
    uint256 public tokenCount;

    // 构造函数，默认将 msg.sender 作为合约所有者
    constructor() ERC721("Azuki", "AZUKI")  {
    }

    //铸造nft
    function mint(address to, string memory tokenURI) public returns (uint256) {
        tokenCount++;
        uint256 tokenId = tokenCount;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return tokenId;
    }
}
