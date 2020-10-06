// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

interface IArgobytesActor {
    // TODO: option to delegatecall?
    struct Action {
        address payable target;
        bytes data;
        bool with_value;
    }

    function callActions(Action[] calldata actions) external payable;
}

contract ArgobytesActor is IArgobytesActor {
    using Address for address payable;

    // we want to receive because we might sweep tokens between actions
    // TODO: be careful not to leave coins here!
    receive() external payable {}

    /**
     * @notice Call arbitrary actions.
     *
     *  transfer tokens to the actions before calling this
     */
    function callActions(Action[] calldata actions) external override payable {
        // TODO: re-entrancy?
        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        for (uint256 i = 0; i < actions.length; i++) {
            // IMPORTANT! it is up to the caller to make sure that they trust this target!
            address payable action_address = actions[i].target;

            if (actions[i].with_value) {
                // TODO: do we want this.balance, or msg.value?
                action_address.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    "ArgobytesActions.execute: external call with value failed"
                );
            } else {
                action_address.functionCall(
                    actions[i].data,
                    "ArgobytesActions.execute: external call failed"
                );
            }
        }

        // refund excess ETH
        // TODO: this is actually a bit of a problem. targets are going to need to know to leave some ETH behind for this
        if (address(this).balance > 0) {
            (bool success, ) = msg.sender.call{value: address(this).balance}(
                ""
            );
            require(success, "ArgobytesActor: REFUND_FAILED");
        }
    }
}
