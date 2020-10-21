// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {ICallee} from "contracts/interfaces/dydx/ICallee.sol";
import {DyDxTypes} from "contracts/interfaces/dydx/DyDxTypes.sol";

interface IArgobytesActor {
    struct Action {
        address payable target;
        bytes data;
        // TODO: sometimes we want to pass all the value,
        //       but there's also cases where we want to do a specific amount
        //       maybe use an enum and have a bytes field that we decode for any extra data?
        bool with_value;
    }

    function callActions(Action[] calldata actions) external payable;
}

contract ArgobytesActor is IArgobytesActor, ICallee {
    using Address for address payable;

    // we want to receive because we might sweep tokens between actions
    // TODO: be careful not to leave coins here!
    receive() external payable {}

    /**
     * @notice Call arbitrary actions.
     *
     *  transfer tokens to the actions before calling this
     */
    function callActions(Action[] calldata actions) public override payable {
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

        // refund excess ETH (other tokens should be handled by the actions)
        if (address(this).balance > 0) {
            (bool success, ) = msg.sender.call{value: address(this).balance}(
                ""
            );
            require(success, "ArgobytesActor: REFUND_FAILED");
        }
    }

    /*
    Entrypoint for dYdX operations.

    TODO: do we care about the sender or accountInfo?
    */
    function callFunction(
        address sender,
        DyDxTypes.AccountInfo calldata accountInfo,
        bytes calldata data
    ) external override {
        return this.callActions(abi.decode(data, (Action[])));
    }
}
