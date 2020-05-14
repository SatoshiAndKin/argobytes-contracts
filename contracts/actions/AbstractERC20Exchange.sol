// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * There are multitudes of possible contracts for SoloArbitrage. AbstractExchange is for interfacing with ERC20.
 * 
 * These contracts should also be written in a way that they can work with any flash lender
 * 
 * Rewrite this to use UniversalERC20? I'm not sure its worth it. this is pretty easy to follow.
 */
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/math/SafeMath.sol";

contract AbstractERC20Modifiers {
    using SafeERC20 for IERC20;

    address constant ZERO_ADDRESS = address(0);

    // this contract must be able to receive ether if it is expected to sweep it
    receive() external payable { }

    /// @dev after the function, send any remaining ether to an address
    modifier sweepLeftoverEther(address payable to) {
        // TODO: can we change "to" here? i'm not sure how modifiers interact

        _;

        uint balance = address(this).balance;

        if (balance > 0) {
            (bool success, ) = to.call{value: balance}("");
            require(success, "AbstractERC20Modifiers.sweepLeftoverEther: ETH transfer failed");
        }
    }

    /// @dev after the function, send any remaining tokens to an address
    modifier sweepLeftoverToken(address to, address token) {
        // TODO: can we change "to" here? i'm not sure how modifiers interact

        _;

        uint balance = IERC20(token).balanceOf(address(this));

        if (balance > 0) {
            IERC20(token).safeTransfer(to, balance);
        }
    }
}

abstract contract AbstractERC20Amounts is AbstractERC20Modifiers {
    struct Amount {
        address maker_token;
        uint256 maker_wei;
        address taker_token;
        uint256 taker_wei;

        bytes4 selector;
        bytes trade_extra_data;
        bytes exchange_data;
        string error;
    }


    function _getAmounts(address token_a, uint256 token_a_amount, address token_b, bytes memory extra_data)
        internal view
        returns (Amount[] memory)
    {
        require(token_a != token_b, "token_a should != token_b");

        Amount[] memory amounts = new Amount[](2);

        // TODO: think more about this. i think we need this because our contract is abstract
        string memory newAmountSignature = "newAmount(address,uint256,address,bytes)";

        // get amounts for trading token_a -> token_b
        // use the same amounts that we used in our ETH trades to keep these all around the same value
        // we can't use try/catch with internal functions, so we have to use call instead
        (bool success, bytes memory returnData) = address(this).staticcall(abi.encodeWithSignature(newAmountSignature, token_b, token_a_amount, token_a, extra_data));
        if (success) {
            amounts[0] = abi.decode(returnData, (Amount));
        }
        // amounts[0] = newAmount(token_b, token_a_amount, token_a, extra_data);

        // TODO: since this uses amounts[0], we need to only do this if the amounts are valid
        // get amounts for trading token_b -> token_a
        // we can't use try/catch with internal functions, so we have to use call instead
        if (amounts[0].maker_wei > 0) {
            (success, returnData) = address(this).staticcall(abi.encodeWithSignature(newAmountSignature, token_a, amounts[0].maker_wei, token_b, extra_data));
            if (success) {
                amounts[1] = abi.decode(returnData, (Amount));
            }
            // amounts[1] = newAmount(token_a, amounts[0].maker_wei, token_b, extra_data);
        }

        return amounts;
    }

    function newAmount(address maker_token, uint taker_wei, address taker_token, bytes memory extra_data)
        public virtual view
        returns (Amount memory);

    function newPartialAmount(address maker_token, uint taker_wei, address taker_token)
        internal pure
        returns (Amount memory)
    {
        Amount memory a = Amount({
            maker_token: maker_token,
            maker_wei: 0,
            taker_token: taker_token,
            taker_wei: taker_wei,
            selector: "",
            trade_extra_data: "",
            exchange_data: "",
            error: ""
        });

        // missing maker_wei and extra_data! you need to set these in your `newAmount`

        return a;
    }
}

abstract contract AbstractERC20Exchange is AbstractERC20Amounts {

    // TODO: i think we should get rid of these generic functions. most every function ignores at least one of the arguments. this should make cleaner contracts and not just be considered gas golfing
    // these functions require that address(this) has an ether/token balance.
    // these functions might have some leftover ETH or src_token in them after they finish, so be sure to use the sweep modifiers on whatever calls these
    // TODO: decide on best order for the arguments
    // TODO: _tradeUniversal? that won't be as gas efficient
    function _tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
    function _tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;
    function _tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes memory extra_data) internal virtual;

    function tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        payable
        sweepLeftoverEther(msg.sender)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        _tradeEtherToToken(to, dest_token, dest_min_tokens, dest_max_tokens, extra_data);
    }

    function tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        sweepLeftoverToken(msg.sender, src_token)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        _tradeTokenToToken(to, src_token, dest_token, dest_min_tokens, dest_max_tokens, extra_data);
    }

    function tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
        external
        sweepLeftoverToken(msg.sender, src_token)
    {
        if (to == address(0x0)) {
            to = msg.sender;
        }

        _tradeTokenToEther(to, src_token, dest_min_tokens, dest_max_tokens, extra_data);
    }
}
