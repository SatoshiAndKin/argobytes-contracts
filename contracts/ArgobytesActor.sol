// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

interface IArgobytesActor {
    struct Action {
        address payable target;
        bytes data;
        bool with_value;
    }

    function callActions(
        Action[] calldata actions
    ) external payable;
}

contract ArgobytesActor is IArgobytesActor {
    using Address for address payable;

    /**
     * @notice Call arbitrary actions.
     *
     *  transfer tokens to the actions before calling this
     */
    function callActions(
        Action[] calldata actions
    ) external payable override {
        // TODO: re-entrancy?
        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        for (uint256 i = 0; i < actions.length; i++) {
            // IMPORTANT! it is up to the caller to make sure that they trust this target!
            address payable action_address = actions[i].target;

            if (actions[i].with_value) {
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
    }
}
