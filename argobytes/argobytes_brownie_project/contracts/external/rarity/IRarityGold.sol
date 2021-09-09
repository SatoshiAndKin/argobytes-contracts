// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

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
