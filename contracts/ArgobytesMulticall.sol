// SPDX-License-Identifier: LGPL-3.0-or-later
/*
Calling just one function on another contract isn't very exciting; you can already do that with your EOA. The ArgobytesMulticall contract's `callActions` function takes a list of multiple contract addresses and functions. If any fail, the whole thing reverts.

This contract is a key part of some action contracts.

This is similar to [MakerDAO's multicall](https://github.com/makerdao/multicall) but with the added ability to transfer ETH.

If you need more complex ways to call multiple actions and move ETH around, you probably just want to write an action contract.

TODO: think about this smore. make it re-use code in ArgobytesProxy? do we even need it anymore?
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";


interface IArgobytesMulticall {

    // TODO: there's also cases where we want to do a specific amount. think more about this
    // TODO: i think we can just make a different Actor contract for them
    // maybe use a "Amount" entry and have a bytes field that we decode for any extra data?
    enum ValueMode {
        None,
        Balance,
        Msg
    }

    // TODO: have a "requireSuccess" bool?
    struct Action {
        address payable target;
        ValueMode value_mode;
        bytes data;
    }

    function callActions(Action[] calldata actions) external payable;
}

contract ArgobytesMulticall is IArgobytesMulticall {
    using Address for address payable;

    // we want to receive because we might sweep tokens between actions
    // TODO: be careful not to leave coins here!
    receive() external payable {}

    /**
     * @notice Call arbitrary actions.
     *
     *  transfer tokens to the actions before calling this
     */
    function callActions(Action[] memory actions) external override payable {
        // TODO: re-entrancy?
        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        for (uint256 i = 0; i < actions.length; i++) {
            // IMPORTANT! it is up to the caller to make sure that they trust this target!

            if (ValueMode(actions[i].value_mode) == ValueMode.None) {
                // if every single action uses value_mode none, the caller should probably just use Multicall.sol instead
                actions[i].target.functionCall(
                    actions[i].data,
                    "ArgobytesActions.callActions external call failed"
                );
            } else if (ValueMode(actions[i].value_mode) == ValueMode.Balance) {
                actions[i].target.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    "ArgobytesActions.callActions external call with balance failed"
                );
            } else {
                // TODO: do we want this.balance, or msg.value?
                actions[i].target.functionCallWithValue(
                    actions[i].data,
                    msg.value,
                    "ArgobytesActions.callActions external call with value failed"
                );
            }
        }
    }
}
