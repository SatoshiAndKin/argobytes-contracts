// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";

interface IArgobytesActor {
    struct Action {
        address payable target;
        bytes data;
        bool with_value;
    }

    function callActions(
        Action[] calldata actions
    ) external payable;

    function callActionsAndFreeOptimal(
        bool free_gas_token,
        bool require_gas_token,
        Action[] calldata actions
    ) external payable;

    function callActionsAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        Action[] calldata actions
    ) external payable;
}

contract ArgobytesActor is IArgobytesActor, LiquidGasTokenUser {
    using Address for address payable;
   
    // transfer tokens to the actions before calling this
    function _callActions(
        Action[] calldata actions
    ) internal {
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

    /**
     * @notice Call arbitrary actions.
     */
    function callActions(
        Action[] calldata actions
    ) external payable override {
        // TODO: re-entrancy?
        _callActions(actions);
    }

    /**
     * @notice Call arbitrary actions and free LGT.
     */
    function callActionsAndFreeOptimal(
        bool free_gas_token,
        bool require_gas_token,
        Action[] calldata actions
    ) external payable override {
        // TODO: re-entrancy?
        uint256 initial_gas = initialGas(free_gas_token);

        _callActions(actions);

        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    /**
     * @notice Call arbitrary actions and free a specific amount of LGT.
     */
    function callActionsAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        Action[] calldata actions
    ) external payable override {
        // TODO: re-entrancy?
        freeGasTokens(gas_token_amount, require_gas_token);

        _callActions(actions);
    }
}
