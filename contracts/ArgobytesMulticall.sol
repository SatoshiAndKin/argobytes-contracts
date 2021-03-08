// SPDX-License-Identifier: LGPL-3.0-or-later
/*
This is similar to MakerDAO's Multicall, but it can also pass value. If you don't need value, Multicall may be better.

It can also be a target for DyDx's flashloans.
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {DyDxTypes, IDyDxCallee} from "contracts/external/dydx/IDyDxCallee.sol";


interface IArgobytesMulticall is IDyDxCallee {

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

    /*
    Entrypoint for dYdX operations (from IDyDxCallee).

    TODO: do we care about the first two args (sender or accountInfo)?
    TODO: flash loans aren't going to play nince with delegatecall
    */
    function callFunction(
        address /*sender*/,
        DyDxTypes.AccountInfo calldata /*accountInfo*/,
        bytes calldata data
    ) external override {
        Action[] memory actions = abi.decode(data, (Action[]));

        return this.callActions(actions);
    }
}
