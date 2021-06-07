// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {ArgobytesAuth, ActionTypes} from "contracts/abstract/ArgobytesAuth.sol";
import {AddressLib} from "contracts/library/AddressLib.sol";
import {BytesLib} from "contracts/library/BytesLib.sol";

/// @dev The target address is not a valid contract
error InvalidTarget();

/// @title simple contract for use with a delegatecall proxy
/// @dev contains a very powerful "execute" function! The owner is in full control!
contract ArgobytesProxy is ArgobytesAuth {
    struct Action {
        address target;
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
    function execute(Action calldata action) public payable returns (bytes memory response) {
        // check auth
        if (msg.sender != owner()) {
            requireAuth(action.target, action.call_type, BytesLib.toBytes4(action.target_calldata));
        }

        // re-entrancy protection?

        if (!Address.isContract(action.target)) {
            revert InvalidTarget();
        }

        // we use the "unchecked" functions because we just checked that `action.target` is a contract
        if (action.call_type == ActionTypes.Call.DELEGATE) {
            response = AddressLib.uncheckedDelegateCall(action.target, action.target_calldata);
        } else {
            // call_type is CALL (or maybe ADMIN)
            response = AddressLib.uncheckedCall(action.target, action.forward_value, action.target_calldata);
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
