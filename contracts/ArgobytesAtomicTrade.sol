// SPDX-License-Identifier: LGPL-3.0-or-later
// Argobytes is Satoshi & Kin's smart contract for arbitrage trading.
// Uses flash loans so that we have near infinite liquidity.
// Uses gas token so that we pay less in miner fees.
// TODO: use address payable once ethabi works with it
// ABIEncodeV2 is not yet supported by rust's ethabi, so be careful how you use it. don't expose new encodings in function args or returns
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/math/SafeMath.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

import {IInvokable} from "interfaces/kollateral/IInvokable.sol";
import {IInvoker} from "interfaces/kollateral/IInvoker.sol";
import {
    KollateralInvokable
} from "interfaces/kollateral/KollateralInvokable.sol";
import {UniversalERC20, SafeERC20, IERC20} from "contracts/UniversalERC20.sol";
import {
    IArgobytesAtomicTrade
} from "interfaces/argobytes/IArgobytesAtomicTrade.sol";
import {Strings2} from "contracts/Strings2.sol";

// https://github.com/kollateral/kollateral/blob/master/lib/static/invoker.ts
// they take a 6bps fee

contract ArgobytesAtomicTrade is IArgobytesAtomicTrade, KollateralInvokable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings2 for address;
    // using Strings2 for bytes;    // we don't need this now that OpenZepplin has call helpers
    using UniversalERC20 for IERC20;

    address internal constant ADDRESS_ZERO = address(0x0);
    address internal constant KOLLATERAL_ETH = address(
        0x0000000000000000000000000000000000000001
    );

    // TODO: get rid of this. do encoding outside of the smart contract
    // this is here because I'm having trouble encoding these types in Rust
    function encodeActions(
        address payable[] memory targets,
        bytes[] memory targets_data,
        bool[] memory with_values
    ) public pure returns (bytes memory encoded_data) {
        uint256 length = targets.length;

        require(
            length == targets_data.length,
            "ArgobytesAtomicTrade.encodeActions: data length does not match targets length"
        );
        require(
            length == with_values.length,
            "ArgobytesAtomicTrade.encodeActions: with_values length does not match targets length"
        );

        Action[] memory actions = new Action[](length);

        for (uint256 i = 0; i < length; i++) {
            actions[i] = Action(targets[i], targets_data[i], with_values[i]);
        }

        encoded_data = abi.encode(actions);
    }

    /**
     * @notice Trade `first_amount` `tokens[0]` and return profits to msg.sender.
     */
    function atomicTrade(
        address kollateral_invoker,
        address[] calldata tokens,
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external override payable {
        // TODO: add deadline to prevent miners doing sneaky things by broadcasting transactions late
        // TODO: if we want to use GSN, we should use `_msgSender()` instead of msg.sender

        uint256 num_tokens = tokens.length;

        require(
            num_tokens > 0,
            "ArgobytesAtomicArbitrage.atomicTrade: tokens.length must be > 0"
        );

        uint256 balance = IERC20(tokens[0]).universalBalanceOf(address(this));

        if (balance >= first_amount) {
            // we have all the funds that we need
            executeSolo(tokens[0], first_amount, encoded_actions);
        } else {
            // we do not have enough token to do this trade ourselves. use kollateral for the remainder
            first_amount -= balance;

            // TODO: try/catch?
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
            // this could still be benificial if we are a liquidity provider on kollateral, so we allow it
        }

        // this contract should now have some tokens in it
        // TODO: it is possible all tokens went to other addresses or to repay the loan. If the caller doesn't want that, they can revert

        // sweep any profits to another address (likely cold storage, but could be a fancy smart wallet, but please not a hot wallet!)
        // because there might be leftovers from some of the trades, we sweep all tokens involved
        // TODO: move this to an internal sweep function?
        for (uint256 i = 0; i < num_tokens; i++) {
            // use univeralERC20 library functions because one of these tokens might actually be ETH
            IERC20 token = IERC20(tokens[i]);

            uint256 ending_amount = token.universalBalanceOf(address(this));

            // we don't emit events ourselves because token transfers already do that for us
            // ETH profits won't emit logs, but it is easy to check balance changes
            // TODO: we could take an address instead of sending back to msg.sender, but this works for our vault which is our main user for now
            token.universalTransfer(msg.sender, ending_amount);
        }
    }

    /**
     * @notice Entrypoint for Kollateral to execute arbitrary actions and then repay what was borrowed from Kollateral (plus a small fee).
     * @dev https://docs.kollateral.co/implementation#creating-your-invokable-smart-contract
     */
    function execute(bytes calldata encoded_actions) external override payable {
        // TODO: open this up once it has been audited
        require(
            currentSender() == address(this),
            "ArgobytesAtomicTrade.execute: Original sender is not this contract"
        );

        // TODO: can we get a revert message if the decode fails?
        Action[] memory actions = abi.decode(encoded_actions, (Action[]));

        uint256 num_actions = actions.length;

        // we could allow 0 actions, but why would we ever want to pay a fee to do nothing?
        require(
            num_actions > 0,
            "ArgobytesAtomicArbitrage.execute: there must be at least one action"
        );

        bool is_current_token_ether = isCurrentTokenEther();
        // IMPORTANT! THIS HAS A UNIQUE ETH ADDRESS! IT DOES NOT USE THE ZERO ADDRESS!
        IERC20 borrowed_token = IERC20(currentTokenAddress());

        if (!is_current_token_ether) {
            // transer tokens to the first action
            // this is easier/cheaper than doing approve+transferFrom

            // we shouldn't do `borrowed_amount = currentTokenAmount()` because we might have had a balance before borrowing anything!
            // we don't need universalBalanceOf because we know this isn't ETH
            uint256 borrowed_amount = borrowed_token.balanceOf(address(this));

            borrowed_token.safeTransfer(actions[0].target, borrowed_amount);
        }

        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        // all that we care about is that we can repay our debts
        // this doesn't have to be an arbitrage trade
        for (uint256 i = 0; i < num_actions; i++) {
            address action_address = actions[i].target;

            // calls to this aren't expected, so lets just block them to be safe
            require(
                action_address != address(this),
                "ArgobytesAtomicArbitrage.execute: calls to self are not allowed"
            );

            // IMPORTANT! An action contract could be designed that keeps tokens for itself.
            // Preventing that will be very difficult (if not impossible).
            // it is up to the caller to make sure that they use contracts that they trust.

            // TODO: this error message probably costs gas than we want. revert traces are probably more helpful
            string memory err = string(
                abi.encodePacked(
                    "ArgobytesAtomicTrade.execute: call #",
                    i.toString(),
                    " to ",
                    action_address.toString(),
                    " failed"
                )
            );

            if (actions[i].with_value) {
                action_address.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    err
                );
            } else {
                action_address.functionCall(actions[i].data, err);
            }
        }

        // TODO: get rid of this when done debugging. they already do these checks and revert for us
        // {
        //     uint256 repay_amount = currentRepaymentAmount();
        //     if (is_current_token_ether) {
        //         uint256 balance = address(this).balance;
        //         if (balance == 0) {
        //             revert(
        //                 "ArgobytesAtomicTrade.execute: No ETH balance was returned by the last action"
        //             );
        //         }
        //         require(
        //             balance >= repay_amount,
        //             "ArgobytesAtomicTrade.execute: Not enough ETH balance to repay kollateral"
        //         );
        //     } else {
        //         uint256 balance = borrowed_token.balanceOf(address(this));
        //         if (balance == 0) {
        //             revert(
        //                 "ArgobytesAtomicTrade.execute: No token balance was returned by the last action"
        //             );
        //         }
        //         require(
        //             balance >= repay_amount,
        //             "ArgobytesAtomicTrade.execute: Not enough token balance to repay kollateral"
        //         );
        //     }
        // }

        repay();
    }

    /**
     * @notice Execute arbitrary actions when we have enough funds without borrowing from anywhere.
     */
    // TODO: private or internal?
    function executeSolo(
        address first_token,
        uint256 first_amount,
        bytes memory encoded_actions
    ) private {
        // TODO: would be nice to have a revert message here if this fails to decode
        // TODO: accept Action[] memory actions directly?
        Action[] memory actions = abi.decode(encoded_actions, (Action[]));

        uint256 num_actions = actions.length;

        // we could allow 0 actions, but why would we ever want that?
        require(
            num_actions > 0,
            "ArgobytesAtomicArbitrage.executeSolo: there must be at least one action"
        );

        // if the first token isn't ETH, transfer it
        // if it is ETH, we will send it with functionCallWithValue
        if (first_token != ADDRESS_ZERO) {
            uint256 first_token_balance = IERC20(first_token)
                .universalBalanceOf(address(this));

            require(
                first_token_balance >= first_amount,
                "ArgobytesAtomicArbitrage.executeSolo: not enough token"
            );

            IERC20(first_token).universalTransfer(
                actions[0].target,
                first_amount
            );
        }

        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        // this does NOT have to end with a profitable arbitrage. If you want that,
        for (uint256 i = 0; i < num_actions; i++) {
            address action_address = actions[i].target;

            // calls to this aren't expected, so lets just block them to be safe
            require(
                action_address != address(this),
                "ArgobytesAtomicArbitrage.executeSolo: calls to self are not allowed"
            );

            // IMPORTANT! An action contract could be designed that keeps profits for itself.
            // Preventing that will be very difficult. This is why other similar contracts take a fee.

            string memory err = string(
                abi.encodePacked(
                    "ArgobytesAtomicTrade.executeSolo: call #",
                    i.toString(),
                    " to ",
                    action_address.toString(),
                    " failed"
                )
            );

            if (actions[i].with_value) {
                action_address.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    err
                );
            } else {
                action_address.functionCall(actions[i].data, err);
            }
        }
    }
}
