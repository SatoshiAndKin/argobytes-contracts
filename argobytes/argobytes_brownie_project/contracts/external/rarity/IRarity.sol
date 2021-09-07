// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IRarity {

    // ERC721
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    // Rarity
    event summoned(address indexed owner, uint _class, uint summoner);
    event leveled(address indexed owner, uint level, uint summoner);

    function next_summoner() external returns (uint);
    function name() external returns (string memory);
    function symbol() external returns (string memory);
    
    function xp(uint) external returns (uint);
    function adventurers_log(uint) external returns (uint);
    function class(uint) external returns (uint);
    function level(uint) external returns (uint);

    function adventure(uint _summoner) external;
    function spend_xp(uint _summoner, uint _xp) external;    
    function level_up(uint _summoner) external;
    function summoner(uint _summoner) external view returns (uint _xp, uint _log, uint _class, uint _level);
    function summon(uint _class) external;
    function xp_required(uint curent_level) external pure returns (uint xp_to_next_level);
    function tokenURI(uint256 _summoner) external view returns (string memory);
    function classes(uint id) external pure returns (string memory description);
}

interface IRarityGold {

    // ERC20
    event Transfer(uint indexed from, uint indexed to, uint amount);
    event Approval(uint indexed from, uint indexed to, uint amount);

    function name() external returns (string memory);
    function symbol() external returns (string memory);
    function decimals() external returns (uint8);
    function totalSupply() external returns (uint);
    function approve(uint from, uint spender, uint amount) external returns (bool);
    function transfer(uint from, uint to, uint amount) external returns (bool);
    function transferFrom(uint executor, uint from, uint to, uint amount) external returns (bool);
    function allowance(uint, uint) external returns (uint);
    function balanceOf(uint) external returns (uint);

    // Rarity Gold
    function wealth_by_level(uint level) external pure returns (uint wealth);
    function claimable(uint summoner) external view returns (uint amount);
    function claim(uint summoner) external;
    function claimed(uint) external returns (uint);
}
