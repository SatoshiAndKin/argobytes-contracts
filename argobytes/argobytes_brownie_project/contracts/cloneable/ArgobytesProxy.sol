// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {ArgobytesAuth, ActionTypes} from "contracts/abstract/ArgobytesAuth.sol";
import {BytesLib} from "contracts/library/BytesLib.sol";

error ActionReverted(address target, bytes target_calldata, bytes errordata);

/// @dev The target address is not a valid contract
error InvalidTarget();

/// @title simple contract for use with a delegatecall proxy
/// @dev contains a very powerful "execute" function! The owner is in full control!
contract ArgobytesProxy is ArgobytesAuth {
    struct Action {
        address payable target;
        ActionTypes.Call call_type;
        bool forward_value;
        bytes target_calldata;
    }

    /**
     * @notice Don't store ETH here outside a transaction!
     * @dev but we do want to be able to receive it in one call and return in another
     */
    receive() external payable {}

    /**
     * @notice Call or delegatecall a function on another contract
     * @notice WARNING! This is essentially a backdoor that allows for anything to happen. Without fancy auth isn't DeFi; this is a personal wallet
     * @dev The owner is allowed to call anything. This is helpful in case funds get somehow stuck
     * @dev The owner can authorize other contracts to cll this contract
     */
    function execute(Action calldata action) public payable returns (bytes memory action_returned) {
        // check auth
        if (msg.sender != owner()) {
            requireAuth(action.target, action.call_type, BytesLib.toBytes4(action.target_calldata));
        }

        // re-entrancy protection?

        // TODO: do we really care about this check? calling a non-contract will give "success" even though thats probably not what people wanted to do
        // however, this would make it possible to send ETH to an arbitrary address
        if (!Address.isContract(action.target)) {
            revert InvalidTarget();
        }

        bool success;

        if (action.call_type == ActionTypes.Call.DELEGATE) {
            (success, action_returned) = action.target.delegatecall(action.target_calldata);
        } else if (action.forward_value) {
            (success, action_returned) = action.target.call{value: msg.value}(action.target_calldata);
        } else {
            (success, action_returned) = action.target.call(action.target_calldata);
        }

        if (!success) {
            revert ActionReverted(action.target, action.target_calldata, action_returned);
        }
    }

    /// @notice Call or delegatecall functions on multiple contracts
    function executeMany(Action[] calldata actions) public payable returns (bytes[] memory responses) {
        responses = new bytes[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            responses[i] = execute(actions[i]);
        }

        return responses;
    }

    // TODO: EIP-165? EIP-721 receiver? those should probably be sent to the owner and then the owner approves this contract
    // TODO: gasless transactions?
}
