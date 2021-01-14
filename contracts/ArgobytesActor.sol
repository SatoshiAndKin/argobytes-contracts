// SPDX-License-Identifier: LGPL-3.0-or-later
/*
This can be useful as a standalone contract, or you can do `contract MyContract is ArgobytesActor`. For an example, see ArgobytesTrader.
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {DyDxTypes} from "contracts/interfaces/dydx/DyDxTypes.sol";

interface IArgobytesActor {

    // TODO: there's also cases where we want to do a specific amount. think more about this
    // TODO: i think we can just make a different Actor contract for them
    // maybe use a "Amount" entry and have a bytes field that we decode for any extra data?
    enum ValueMode {
        None,
        Balance,
        Msg
    }

    struct Action {
        address payable target;
        bytes data;
        uint8 value_mode;
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

            if (ValueMode(actions[i].value_mode) == ValueMode.None) {
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

    function withdrawBalance(address to) public {
        withdraw(to, address(this).balance);
    }

    function withdraw(address to, uint256 amount) public {
        (bool success, ) = msg.sender.call{value: amount}(
            ""
        );
        require(success, "ArgobytesActor !withdraw");
    }
}
