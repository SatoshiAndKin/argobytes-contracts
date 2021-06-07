// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";

/// @title Call multiple contraacts
/** @dev
Calling just one function on another contract isn't very exciting; you can already do that with your EOA. The ArgobytesMulticall contract's `callActions` function takes a list of multiple contract addresses and functions. If any fail, the whole thing reverts.

This contract is a key part of some action contracts.

This is similar to [MakerDAO's multicall](https://github.com/makerdao/multicall) but with the added ability to transfer ETH.

If you need more complex ways to call multiple actions and move ETH around, you probably just want to write an action contract.

TODO: think about this more. make it re-use code in ArgobytesProxy? do we even need it anymore?
 */
contract ArgobytesMulticall {
    /// @dev if you need to send specific amounts of ETH or allow failure, you should probably use a different contract
    enum ValueMode {None, Balance, Msg}

    /// @notice a target and its calldata
    struct Action {
        address payable target;
        ValueMode value_mode;
        bytes data;
    }

    /// @notice we want to receive because we might sweep tokens between actions
    /// @dev be careful not to leave coins here!
    receive() external payable {}

    /// @notice Call arbitrary actions
    /// @dev transfer tokens to the actions before calling this function
    function callActions(Action[] memory actions) external payable {
        // TODO: re-entrancy?
        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        for (uint256 i = 0; i < actions.length; i++) {
            // IMPORTANT! it is up to the caller to make sure that they trust this target!

            if (ValueMode(actions[i].value_mode) == ValueMode.None) {
                // if every single action uses value_mode none, the caller should probably just use Multicall.sol instead
                Address.functionCall(
                    actions[i].target,
                    actions[i].data,
                    "ArgobytesActions.callActions external call failed"
                );
            } else if (ValueMode(actions[i].value_mode) == ValueMode.Balance) {
                Address.functionCallWithValue(
                    actions[i].target,
                    actions[i].data,
                    address(this).balance,
                    "ArgobytesActions.callActions external call with balance failed"
                );
            } else {
                // TODO: do we want this.balance, or msg.value?
                Address.functionCallWithValue(
                    actions[i].target,
                    actions[i].data,
                    msg.value,
                    "ArgobytesActions.callActions external call with value failed"
                );
            }
        }
    }
}
