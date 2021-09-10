// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IRarityAdventure {
    function scout(uint summoner) external returns (uint reward);
    function adventure(uint summoner) external returns (uint reward);
}
