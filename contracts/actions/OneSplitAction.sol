/**
 * Split a trade across multiple other exchange actions.
 * we will probably want a more advanced contract that can enable/disable different exchanges to keep gas costs down.
 */
pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20} from "contracts/UniversalERC20.sol";
import {IOneSplit} from "interfaces/onesplit/IOneSplit.sol";

/*
extra_data for all methods is (uint256 parts, uint256 disable_flags)

parts: I'm 95% sure this is the number of chunks to split this order into. its a uint256. seems like that could be smaller

disable_flags: https://github.com/CryptoManiacsZone/1split/blob/d8fae717176e7db86877535940e4429ff0d60752/contracts/IOneSplit.sol

*/

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
// TODO: i think we just want the modifiers. we need to be able to enable/disable exchanges.
// TODO: maybe AbstractERC20Exchange should take arbitrary data!
contract OneSplitAction is AbstractERC20Exchange {

    IOneSplit _one_split;

    constructor(address one_split) public {
        _one_split = IOneSplit(one_split);
    }

    // TODO: helper here that sets allowances and then transfers? i think IUniswapExchange might already have all the methods we need though
    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256, // dest_max_tokens
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(extra_data, (uint256, uint256));

        uint256 src_balance = address(this).balance;
        require(src_balance > 0, "NO_ETH_BALANCE");

        // do the actual swap
        _one_split.goodSwap{value: src_balance}(IERC20(address(0x0)), IERC20(dest_token), src_balance, dest_min_tokens, parts, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(dest_balance >= dest_min_tokens, "LOW_DEST_BALANCE");

        payable(to).transfer(dest_balance);
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256, // dest_max_tokens
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(extra_data, (uint256, uint256));

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "NO_BALANCE");

        // approve tokens
        IERC20(src_token).approve(address(_one_split), src_balance);

        // do the actual swap
        _one_split.goodSwap(IERC20(src_token), IERC20(dest_token), src_balance, dest_min_tokens, parts, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(dest_balance >= dest_min_tokens, "LOW_DEST_BALANCE");

        IERC20(dest_token).transfer(to, dest_balance);
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256, // dest_max_tokens
        bytes memory extra_data
    ) internal override {
        (uint256 parts, uint256 disable_flags) = abi.decode(extra_data, (uint256, uint256));

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "NO_BALANCE");

        // approve tokens
        IERC20(src_token).approve(address(_one_split), src_balance);

        // do the actual swap
        _one_split.goodSwap(IERC20(src_token), IERC20(address(0x0)), src_balance, dest_min_tokens, parts, disable_flags);

        // forward the tokens that we bought
        uint256 dest_balance = address(this).balance;
        require(dest_balance >= dest_min_tokens, "LOW_DEST_BALANCE");

        payable(to).transfer(dest_balance);
    }

    // TODO: _tradeUniversal? it would have more if/elses, which makes it harder to reason about. probably higher gas too. but less gas to deploy.
}
