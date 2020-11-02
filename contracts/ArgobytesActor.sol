// SPDX-License-Identifier: LGPL-3.0-or-later
/*
This can be useful as a standalone contract, or you can do `contract MyContract is ArgobytesActor`. For an example, see ArgobytesTrader.
*/
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {DyDxTypes} from "contracts/interfaces/dydx/DyDxTypes.sol";

interface IArgobytesActor {
    struct Action {
        address payable target;
        bytes data;
        // TODO: there's also cases where we want to do a specific amount. think more about this
        //       maybe use an enum and have a bytes field that we decode for any extra data?
        bool with_balance;
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

            if (actions[i].with_balance) {
                actions[i].target.functionCallWithValue(
                    actions[i].data,
                    address(this).balance,
                    "ArgobytesActions.execute: external call with balance failed"
                );
            } else if (actions[i].with_value) {
                // TODO: do we want this.balance, or msg.value?
                actions[i].target.functionCallWithValue(
                    actions[i].data,
                    msg.value,
                    "ArgobytesActions.execute: external call with value failed"
                );
            } else {
                actions[i].target.functionCall(
                    actions[i].data,
                    "ArgobytesActions.execute: external call failed"
                );
            }
        }

        // refund excess ETH (other tokens should be handled by the actions)
        // TODO: think about this more. it very likely needs to be made optional! or at least only refund up to msg.value
        if (address(this).balance > 0) {
            (bool success, ) = msg.sender.call{value: address(this).balance}(
                ""
            );
            require(success, "ArgobytesActor: REFUND_FAILED");
        }
    }
}
