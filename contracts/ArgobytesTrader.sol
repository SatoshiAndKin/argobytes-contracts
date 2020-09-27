// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns LiquidGasToken (or compatible contracts)
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@OpenZeppelin/token/ERC20/SafeERC20.sol";

import {IArgobytesActor} from "./ArgobytesActor.sol";

interface IArgobytesTrader {
    struct Borrow {
        IERC20 token;
        uint256 amount;
        address dest;
    }

    function atomicArbitrage(
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external payable returns (uint256 primary_profit);

    function atomicTrade(
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external payable;

}

// TODO: this isn't right. this works for the owner account, but needs more thought for authenticating a bot
// TODO: maybe have a function approvedAtomicAbitrage that calls transferFrom. and another that that assumes its used from the owner of the funnds with delegatecall
contract ArgobytesTrader is IArgobytesTrader {
    using SafeERC20 for IERC20;

    // we want to receive because we might sweep tokens between actions
    // TODO: be careful not to leave coins here!
    receive() external payable {}

    function atomicArbitrage(
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external payable override returns (uint256 primary_profit) {
        uint256[] memory start_balances = new uint256[](borrows.length);

        // record starting token balances to check for increases
        // transfer tokens from msg.sender to arbitrary destinations
        // TODO: what about ETH balances? 
        for (uint256 i = 0; i < borrows.length; i++) {
            start_balances[i] = borrows[i].token.balanceOf(msg.sender);

            // TODO: think about this and approvals more
            borrows[i].token.safeTransferFrom(msg.sender, borrows[i].dest, borrows[i].amount);
        }

        // we call a seperate contract because we don't want any sneaky transferFroms
        // this contract (or the actions) MUST return all borrowed tokens to msg.sender
        // TODO: pass ETH along? this might be helpful for exchanges like 0x. maybe better to borrow WETH for the action
        argobytes_actor.callActions{value: msg.value}(actions);

        // make sure the source's balances did not decrease
        // we allow it to be equal because it's possible that we got our profits on another token or from LP fees
        for (uint256 i = 0; i < borrows.length; i++) {
            // return any tokens that the actions didn't already return
            uint256 this_balance = borrows[i].token.balanceOf(address(this));

            borrows[i].token.safeTransfer(msg.sender, this_balance);

            // make sure the balance increased
            uint256 end_balance = borrows[i].token.balanceOf(msg.sender);

            require(end_balance >= start_balances[i]);

            if (i == 0) {
                // TODO? return the profit in all tokens so a caller can decide if the trade is worthwhile
                // we do not need safemath's `sub` here because we check for `end_balance < start_balance` above
                primary_profit = end_balance - start_balances[i];
            }
        }
    }

    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice You'll need to call this from another smart contract that has authentication.
     */
    function atomicTrade(
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external payable override {
        // transfer tokens from msg.sender to arbitrary destinations
        // this is dangerous! be careful with this!
        for (uint256 i = 0; i < borrows.length; i++) {
            // TODO: think about this and approvals more
            borrows[i].token.safeTransferFrom(msg.sender, borrows[i].dest, borrows[i].amount);
        }

        // TODO: pass ETH along
        // we call a seperate contract because we don't want any sneaky transferFroms
        argobytes_actor.callActions{value: msg.value}(actions);
    }

    // TODO? function that uses kollateral to do callActions
}
