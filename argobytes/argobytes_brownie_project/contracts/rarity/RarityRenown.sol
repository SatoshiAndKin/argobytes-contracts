// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;
/*
Renown cannot be traded with other summonerr
However, it can be exchanged between different factions
*/

import {RarityBase} from "./abstract/RarityBase.sol";

contract RarityRenown is RarityBase {
    /// @dev inFaction to outFaction exchange rate. set by outFaction
    // TODO: some sort of AMM price based on total supply?
    mapping(address => mapping(address => uint)) public renownExchangeRate;

    // TODO: mapping to store proposed exchange rates. both sides have to accept to change

    /// @dev faction => amount
    mapping(address => uint) public totalSupply;
    /// @dev faction => summoner => amount
    mapping(address => mapping(uint => uint)) public balanceOf;

    event SetExchangeRate(address indexed inFaction, address indexed outFaction, uint amount);
    event RenownUp(address indexed faction, uint indexed summoner, uint amount);
    event RenownDown(address indexed faction, uint indexed summoner, uint amount);

    ///
    /// Renown burning
    ///
    
    /// @notice Delete renown from a summoner
    function burn(uint summoner, uint amount) external {
        _burn(summoner, amount, msg.sender);
    }

    function _burn(uint summoner, uint amount, address faction) internal {
        totalSupply[faction] -= amount;
        balanceOf[faction][summoner] -= amount;
        emit RenownDown(faction, summoner, amount);
    }

    ///
    /// Renown exchanging
    ///
    
    /// @notice exchange renown between factions
    function exchangeRenown(uint summoner, address[] calldata path, uint inAmount, uint minOutAmount) auth(summoner)
        external returns (uint)
    {
        uint pathLength = path.length;
        require(pathLength >= 2, "!path");

        uint exchanged = inAmount;
        for (uint i; i < pathLength - 1; i++) {
            address inFaction = path[i];
            address outFaction = path[i + 1];

            uint roundInAmount;
            (roundInAmount, exchanged) = getExchangeRenownAmount(inFaction, exchanged, outFaction);

            _burn(summoner, roundInAmount, inFaction);
            _mint(summoner, exchanged, outFaction);
        }

        require(minOutAmount <= exchanged, "!outAmount");
    }

    function getExchangeRenownAmount(address inFaction, uint inAmount, address outFaction)
        public returns (uint roundInAmount, uint outAmount)
    {
        uint exchangeRate = renownExchangeRate[inFaction][outFaction];
        require(exchangeRate > 0, "!rate");

        outAmount = inAmount * exchangeRate / 1e18;

        roundInAmount = outAmount * 1e18 / exchangeRate;
    }

    /// @dev 1e18 = 1.0
    /// TODO: auto scale the price?
    function setExchangeRate(address inFaction, uint rate) external {
        // inFaction -> outFaction -> amount
        renownExchangeRate[inFaction][msg.sender] = rate;

        emit SetExchangeRate(inFaction, msg.sender, rate);
    }

    ///
    /// Renown minting
    ///
    
    /// @notice Create renown for a summoner
    function mint(uint summoner, uint amount) external {
        _mint(summoner, amount, msg.sender);
    }

    function _mint(uint summoner, uint amount, address faction) internal {
        totalSupply[faction] += amount;
        balanceOf[faction][summoner] += amount;
        emit RenownUp(faction, summoner, amount);
    }
}
