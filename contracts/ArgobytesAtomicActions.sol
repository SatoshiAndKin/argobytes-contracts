// SPDX-License-Identifier: LGPL-3.0-or-later
// Argobytes is Satoshi & Kin's smart contract for flash-loaned atomic arbitrage trading.
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Address} from "@OpenZeppelin/utils/Address.sol";
// import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {IInvokable} from "contracts/interfaces/kollateral/IInvokable.sol";
import {IInvoker} from "contracts/interfaces/kollateral/IInvoker.sol";
import {
    KollateralInvokable
} from "contracts/interfaces/kollateral/KollateralInvokable.sol";
import {UniversalERC20, SafeERC20, IERC20} from "contracts/UniversalERC20.sol";
import {
    IArgobytesAtomicActions
} from "contracts/interfaces/argobytes/IArgobytesAtomicActions.sol";

// import {Strings2} from "contracts/Strings2.sol";

// https://github.com/kollateral/kollateral/blob/master/lib/static/invoker.ts
// they take a 6bps fee
// TODO: support any.sender
contract ArgobytesAtomicActions is
    IArgobytesAtomicActions,
    KollateralInvokable
{
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // using Strings for uint256;
    // using Strings2 for address;
    // using Strings2 for bytes;    // we don't need this now that OpenZepplin has call helpers
    using UniversalERC20 for IERC20;

    address internal constant ADDRESS_ZERO = address(0x0);
    address internal constant KOLLATERAL_ETH = address(
        0x0000000000000000000000000000000000000001
    );

    // this can be helpful to call from another contract with delegatecall (though I should check the gas costs to see if it makes sense)
    // this doesn't sweep any tokens for you! if you need to interact with tokens, call atomicTrades
    function atomicActions(Action[] calldata actions)
        external
        override
        payable
    {
        _executeSolo(ADDRESS_ZERO, 0, actions);
    }

    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice You'll need to call this from another smart contract.
     */
    function atomicTrades(
        address kollateral_invoker,
        address[] calldata tokens,
        uint256 first_amount,
        Action[] calldata actions
    ) external override payable {
        uint256 num_tokens = tokens.length;

        require(
            num_tokens > 0,
            "ArgobytesAtomicArbitrage.atomicTrades: tokens.length must be > 0"
        );

        uint256 balance = IERC20(tokens[0]).universalBalanceOf(address(this));

        if (balance >= first_amount) {
            // we have all the funds that we need
            _executeSolo(tokens[0], first_amount, actions);
        } else {
            // we do not have enough token to do this trade ourselves. use kollateral for the remainder
            first_amount -= balance;

            // TODO: how efficient is this?
            bytes memory encoded_actions = abi.encode(actions);

            if (tokens[0] == ADDRESS_ZERO) {
                // use kollateral's address for ETH instead of the zero address we use
                IInvoker(kollateral_invoker).invoke(
                    address(this),
                    encoded_actions,
                    KOLLATERAL_ETH,
                    first_amount
                );
            } else {
                IInvoker(kollateral_invoker).invoke(
                    address(this),
                    encoded_actions,
                    tokens[0],
                    first_amount
                );
            }

            // kollateral ensures that we repaid our debts, but it doesn't require profit beyond that
            // this could still be benificial if we are a liquidity provider on kollateral (or one of the exchanges), so we allow it
        }

        // unless everything went to paying kollateral fees, this contract should now have some tokens in it

        // sweep any tokens to another address
        // there might be leftovers from some of the trades, so we sweep all tokens involved
        for (uint256 i = 0; i < num_tokens; i++) {
            // use univeralERC20 library functions because one of these tokens might actually be ETH
            IERC20 token = IERC20(tokens[i]);

            uint256 ending_amount = token.universalBalanceOf(address(this));

            // we don't emit events ourselves because token transfers already do that for us
            // ETH profits won't emit logs, but it is easy to check balance changes
            // TODO: we could have a `address to` param instead of sending to msg.sender, but this works for our purposes for now
            // for most cases, you probably just want to set the "to" on one the last action to your destination
            token.universalTransfer(msg.sender, ending_amount);
        }
    }

    /**
     * @notice Entrypoint for Kollateral to execute arbitrary actions and then repay what was borrowed from Kollateral (plus a small fee).
     * @dev https://docs.kollateral.co/implementation#creating-your-invokable-smart-contract
     */
    function execute(bytes calldata encoded_actions) external override payable {
        // only allow calls to execute from our `atomicActions` function
        // TODO: do we want this check? what safety is added? we never leave coins here so it should be fine
        // require(
        //     currentSender() == address(this),
        //     "ArgobytesAtomicActions.execute: Original sender is not this contract"
        // );

        Action[] memory actions = abi.decode(encoded_actions, (Action[]));

        uint256 num_actions = actions.length;

        // we could allow 0 actions, but why would we ever want to pay a fee to do nothing?
        require(
            num_actions > 0,
            "ArgobytesAtomicArbitrage.execute: there must be at least one action"
        );

        // IMPORTANT! THIS HAS A UNIQUE ETH ADDRESS! IT DOES NOT USE THE ZERO ADDRESS!
        IERC20 borrowed_token = IERC20(currentTokenAddress());

        if (!isCurrentTokenEther()) {
            // transer tokens to the first action
            // this is easier/cheaper than doing approve+transferFrom

            // we shouldn't do `borrowed_amount = currentTokenAmount()` because we might have had a balance before borrowing anything!
            // we don't need universalBalanceOf because we know this isn't ETH
            uint256 borrowed_amount = borrowed_token.balanceOf(address(this));

            borrowed_token.safeTransfer(actions[0].target, borrowed_amount);
        }

        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        // this doesn't have to be an arbitrage trade
        // all that we care about is that we can repay our debts
        for (uint256 i = 0; i < num_actions; i++) {
            // IMPORTANT! it is up to the caller to make sure that they trust this target!
            address action_address = actions[i].target;

            // calls to this aren't expected, so lets just block them to be safe
            require(
                action_address != address(this),
                "ArgobytesAtomicArbitrage.execute: calls to self are not allowed"
            );

            // TODO: this error message probably costs more gas than we want to spend
            // string memory err = string(
            //     abi.encodePacked(
            //         "ArgobytesAtomicActions.execute: call #",
            //         i.toString(),
            //         " to ",
            //         action_address.toString(),
            //         " failed"
            //     )
            // );

            if (actions[i].with_value) {
                action_address.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    "ArgobytesAtomicActions.execute: external call with value failed"
                );
            } else {
                action_address.functionCall(
                    actions[i].data,
                    "ArgobytesAtomicActions.execute: external call failed"
                );
            }
        }

        // TODO: get rid of this when done debugging. `repay` already does these checks it just has no revert reasons
        // {
        //     uint256 repay_amount = currentRepaymentAmount();
        //     if (is_current_token_ether) {
        //         uint256 balance = address(this).balance;
        //         if (balance == 0) {
        //             revert(
        //                 "ArgobytesAtomicActions.execute: No ETH balance was returned by the last action"
        //             );
        //         }
        //         require(
        //             balance >= repay_amount,
        //             "ArgobytesAtomicActions.execute: Not enough ETH balance to repay kollateral"
        //         );
        //     } else {
        //         uint256 balance = borrowed_token.balanceOf(address(this));
        //         if (balance == 0) {
        //             revert(
        //                 "ArgobytesAtomicActions.execute: No token balance was returned by the last action"
        //             );
        //         }
        //         require(
        //             balance >= repay_amount,
        //             "ArgobytesAtomicActions.execute: Not enough token balance to repay kollateral"
        //         );
        //     }
        // }

        repay();
    }

    /**
     * @notice Execute arbitrary actions when we have enough funds without borrowing from anywhere.
     */
    function _executeSolo(
        address first_token,
        uint256 first_amount,
        Action[] calldata actions
    ) internal {
        uint256 num_actions = actions.length;

        // we could allow 0 actions, but why would we ever want that?
        require(
            num_actions > 0,
            "ArgobytesAtomicArbitrage._executeSolo: there must be at least one action"
        );

        // if the first token isn't ETH, transfer it
        // if it is ETH, we will send it with functionCallWithValue
        if (first_token != ADDRESS_ZERO) {
            // we don't need to use the universal functions here since we know this isn't ETH
            uint256 first_token_balance = IERC20(first_token).balanceOf(
                address(this)
            );

            require(
                first_token_balance >= first_amount,
                "ArgobytesAtomicArbitrage._executeSolo: not enough token"
            );

            // we don't need to use the universal functions here since we know this isn't ETH
            IERC20(first_token).safeTransfer(actions[0].target, first_amount);
        }

        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        for (uint256 i = 0; i < num_actions; i++) {
            // IMPORTANT! it is up to the caller to make sure that they trust this target!
            address action_address = actions[i].target;

            // calls to this aren't expected, so lets just block them to be safe
            require(
                action_address != address(this),
                "ArgobytesAtomicArbitrage._executeSolo: calls to self are not allowed"
            );

            // TODO: this error message probably costs more gas than we want to spend
            // string memory err = string(
            //     abi.encodePacked(
            //         "ArgobytesAtomicActions._executeSolo: call #",
            //         i.toString(),
            //         " to ",
            //         action_address.toString(),
            //         " failed"
            //     )
            // );

            if (actions[i].with_value) {
                action_address.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    "ArgobytesAtomicActions.execute: external call with value failed"
                );
            } else {
                action_address.functionCall(
                    actions[i].data,
                    "ArgobytesAtomicActions.execute: external call failed"
                );
            }
        }
    }
}
