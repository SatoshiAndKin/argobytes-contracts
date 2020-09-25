// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns LiquidGasToken (or compatible contracts)
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@OpenZeppelin/token/ERC20/SafeERC20.sol";

import {IArgobytesActor} from "./ArgobytesActor.sol";
import {LiquidGasTokenUser} from "./LiquidGasTokenUser.sol";

interface IArgobytesTrader {
    struct Borrow {
        IERC20 token;
        uint256 amount;
        address dest;
    }

    function argobytesArbitrage(
        bool free_gas_token,
        bool require_gas_token,
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external returns (uint256 primary_profit);

    function argobytesTrade(
        bool free_gas_token,
        bool require_gas_token,
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external;

}

contract ArgobytesTrader is IArgobytesTrader, LiquidGasTokenUser {
    using SafeERC20 for IERC20;

    function argobytesArbitrage(
        bool free_gas_token,
        bool require_gas_token,
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external override returns (uint256 primary_profit) {
        uint256 initial_gas = initialGas(free_gas_token);

        uint256[] memory start_balances = new uint256[](borrows.length);

        // record starting token balances to check for increases
        // transfer tokens from msg.sender to arbitrary destinations
        for (uint256 i = 0; i < borrows.length; i++) {
            start_balances[i] = borrows[i].token.balanceOf(msg.sender);

            // approvals need to be setup!
            borrows[i].token.safeTransferFrom(msg.sender, borrows[i].dest, borrows[i].amount);
        }

        // we call a seperate contract because we don't want any sneaky transferFroms
        // this contract (or the actions) MUST return all borrowed tokens to msg.sender
        argobytes_actor.callActions(actions);

        // make sure our balances did not decrease
        // we allow it to be equal because it's possible that we got our profits on another token or from LP fees
        for (uint256 i = 0; i < borrows.length; i++) {
            uint256 end_balance = borrows[i].token.balanceOf(msg.sender);

            require(end_balance >= start_balances[i]);

            if (i == 0) {
                // TODO? return the profit in all tokens so a caller can decide if the trade is worthwhile
                // we do not need safemath's `sub` here because we check for `end_balance < start_balance` above
                primary_profit = end_balance - start_balances[i];
            }
        }

        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    /**
     * @notice Transfer `first_amount` `tokens[0]`, call some functions, and return tokens to msg.sender.
     * @notice You'll need to delegateCall this from another smart contract that has authentication.
     */
    function argobytesTrade(
        bool free_gas_token,
        bool require_gas_token,
        Borrow[] calldata borrows,
        IArgobytesActor argobytes_actor,
        IArgobytesActor.Action[] calldata actions
    ) external override {
        // TODO: add something to this
        uint256 initial_gas = initialGas(free_gas_token);

        // transfer tokens from msg.sender to arbitrary destinations
        // this is dangerous! be careful with this!
        for (uint256 i = 0; i < borrows.length; i++) {
            // approvals need to be setup!
            // TODO: think about this more. i think delegateCall means msg.sender 
            borrows[i].token.safeTransfer(borrows[i].dest, borrows[i].amount);
        }

        // we call a seperate contract because we don't want any sneaky transferFroms
        argobytes_actor.callActions(actions);

        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    // TODO? function that uses kollateral to do callActions
}
