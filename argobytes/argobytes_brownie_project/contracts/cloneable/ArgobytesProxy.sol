// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.5;

import {AddressLib, CallReverted, InvalidTarget} from "contracts/library/AddressLib.sol";

import {ArgobytesAuth, ActionTypes} from "contracts/abstract/ArgobytesAuth.sol";

/// @title simple contract for use with a delegatecall proxy
/// @dev contains a very powerful "execute" function! The owner is in full control!
contract ArgobytesProxy is ArgobytesAuth {
    struct Action {
        address payable target;
        ActionTypes.Call call_type;
        bytes data;
    }

    /**
     * @notice Call or delegatecall a function on another contract
     * @notice WARNING! This is essentially a backdoor that allows for anything to happen. Without fancy auth isn't DeFi; this is a personal wallet
     * @dev The owner is allowed to call anything. This is helpful in case funds get somehow stuck
     * @dev The owner can authorize other contracts to call this contract
     * TODO: do we care about the return data?
     */
    function execute(Action calldata action) public payable returns (bytes memory action_returned) {
        // check auth
        if (msg.sender != owner()) {
            requireAuth(action.target, action.call_type, bytes4(action.data[0:4]));
        }

        // TODO: re-entrancy protection? i think our auth check is sufficient

        // TODO: do we really care about this check? calling a non-contract will give "success" even though thats probably not what people wanted to do
        // however, this would make it possible to send ETH to an arbitrary address
        if (!AddressLib.isContract(action.target)) {
            revert InvalidTarget(action.target);
        }

        bool success;

        if (action.call_type == ActionTypes.Call.DELEGATE) {
            (success, action_returned) = action.target.delegatecall(action.data);
        } else {
            // TODO: option to send ETH value?
            (success, action_returned) = action.target.call(action.data);
        }

        if (!success) {
            revert CallReverted(action.target, action.data, action_returned);
        }
    }

    /// @notice Call or delegatecall functions on multiple contracts
    // TODO: do we care about the return data?
    function executeMany(Action[] calldata actions) public payable returns (bytes[] memory responses) {
        uint256 num_actions = actions.length;

        responses = new bytes[](num_actions);

        for (uint256 i = 0; i < num_actions; i++) {
            responses[i] = execute(actions[i]);
        }

        return responses;
    }

    // TODO: EIP-165? EIP-721 receiver?
    // TODO: gasless transactions?
}
