// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IRarityAdventure {
    event Transfer(uint indexed from, uint indexed to, uint amount);
    event Approval(uint indexed from, uint indexed to, uint amount);

    function scout(uint summoner) external returns (uint reward);
    function adventure(uint summoner) external returns (uint reward);

    function approve(uint from, uint spender, uint amount) external returns (bool);
    function transfer(uint from, uint to, uint amount) external returns (bool);
    function transferFrom(uint executor, uint from, uint to, uint amount) external returns (bool);
}
