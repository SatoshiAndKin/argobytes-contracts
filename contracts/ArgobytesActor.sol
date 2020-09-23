// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {IArgobytesActor} from "contracts/interfaces/argobytes/IArgobytesActor.sol";

contract ArgobytesActor is IArgobytesActor {
    using Address for address payable;

    /**
     * @notice Call arbitrary actions.
     */
    function callActions(
        Action[] calldata actions
    ) external override {
        // tokens should already have been transfered to the actions

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