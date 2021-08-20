// SPDX-License-Identifier: MPL-2.0
// TODO: rethink this
pragma solidity 0.8.7;

import {ArgobytesAuth} from "contracts/abstract/ArgobytesAuth.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";
import {ArgobytesMulticall} from "contracts/ArgobytesMulticall.sol";

error BadArbitrage(IERC20 token, uint256 start_amount, uint256 end_amount);

/// @title Trade ERC20 tokens
contract ArgobytesTrader {
    struct Borrow {
        uint256 amount;
        IERC20 token;
        address dest;
    }

    /**
     * @dev ArgobytesProxy delegatecall actions can use this, but only safely from the owner
     * @notice Make atomic arbitrage trades
     */
    function atomicArbitrage(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) public payable {
        uint256 num_borrows = borrows.length;
        uint256[] memory start_balances = new uint256[](num_borrows);

        // record starting token balances to check for increases
        // transfer tokens to arbitrary destinations
        // TODO: what about ETH balances?
        // TODO: the common thing is going to be send tokens to the first action. make that a default destination?
        for (uint256 i = 0; i < num_borrows; i++) {
            // TODO: do we want this address(0) check? i think it will be helpful in the case where the clone is holding the coins
            if (borrow_from == address(0)) {
                start_balances[i] = borrows[i].token.balanceOf(address(this));
                SafeERC20.safeTransfer(borrows[i].token, borrows[i].dest, borrows[i].amount);
            } else {
                start_balances[i] = borrows[i].token.balanceOf(borrow_from);
                SafeERC20.safeTransferFrom(borrows[i].token, borrow_from, borrows[i].dest, borrows[i].amount);
            }
        }

        // we call this as a seperate contract because we don't want any sneaky transferFroms
        // this contract (or the actions) MUST return all borrowed tokens to `borrow_from` (or this contract)
        // TODO: pass ETH along? this might be helpful for exchanges like 0x. maybe better to borrow WETH9 for the action
        argobytes_multicall.callActions(actions);

        // make sure the borrowed balances did not decrease
        // we allow it to be equal because it's possible that we got our profits on another token or from LP fees
        for (uint256 i = 0; i < num_borrows; i++) {
            uint256 end_balance = borrows[i].token.balanceOf(address(this));

            if (borrow_from != address(0)) {
                // return any tokens that the actions didn't already return
                SafeERC20.safeTransfer(borrows[i].token, borrow_from, end_balance);

                end_balance = borrows[i].token.balanceOf(borrow_from);
            }

            if (end_balance < start_balances[i]) {
                revert BadArbitrage(borrows[i].token, start_balances[i], end_balance);
            }
        }

        // TODO: refund excess ETH?
    }

    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice this might as well be called `function rugpull` with the transfers for anything. be careful with approvals here!
     * @notice You'll need to call this from another smart contract that has authentication!
     * @notice Dangerous ArgobytesProxy execute target
     */
    function atomicTrade(
        address withdraw_from,
        Borrow[] calldata withdraws,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) external payable {
        // transfer tokens from msg.sender to arbitrary destinations
        // this is dangerous! be careful with this!
        for (uint256 i = 0; i < withdraws.length; i++) {
            // TODO: think about this and approvals more
            if (withdraw_from == address(0)) {
                SafeERC20.safeTransfer(withdraws[i].token, withdraws[i].dest, withdraws[i].amount);
            } else {
                SafeERC20.safeTransferFrom(withdraws[i].token, withdraw_from, withdraws[i].dest, withdraws[i].amount);
            }
        }

        // if you want to ensure that there was a gain in some token, add a requireERC20Balance or requireBalance action
        argobytes_multicall.callActions(actions);

        // TODO: refund excess ETH?
    }

    /// @notice safety check for the end of your atomicTrade or atomicArbitrage actions
    function requireERC20Balance(
        IERC20 token,
        address who,
        uint256 min_balance
    ) public {
        require(token.balanceOf(who) >= min_balance, "ArgobytesTrader !balance");
    }

    /// @notice safety check for the end of your atomicTrade or atomicArbitrage actions
    function requireBalance(address who, uint256 min_balance) public {
        require(who.balance >= min_balance, "ArgobytesTrader !balance");
    }

    /// @notice Like atomicArbitrage, but makes sure that `argobytes_multicall` is an approved contract.
    /// @notice This should be safe to approve bots to use. At least thats the plan. Need an audit.
    function safeAtomicArbitrage(
        address borrow_from,
        Borrow[] calldata borrows,
        ArgobytesMulticall argobytes_multicall,
        ArgobytesMulticall.Action[] calldata actions
    ) public payable {
        // TODO: make sure this multicall contract is approved
        require(false, "ArgobytesTrader.safeAtomicArbitrage !argobytes_multicall");

        atomicArbitrage(borrow_from, borrows, argobytes_multicall, actions);
    }
}
