// SPDX-License-Identifier: LGPL-3.0-or-later
// base class for clone targets
// contains a very powerful "execute" function! The owner is in full control!
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {ArgobytesFactory} from "contracts/ArgobytesFactory.sol";
import {ArgobytesAuth, ArgobytesAuthTypes} from "contracts/abstract/ArgobytesAuth.sol";
import {AddressLib} from "contracts/library/AddressLib.sol";
import {BytesLib} from "contracts/library/BytesLib.sol";

contract ArgobytesProxy is ArgobytesAuth {

    struct Action {
        address target;
        ArgobytesAuthTypes.Call call_type;
        bool forward_value;
        bytes target_calldata;
    }

    /*
     * we shouldn't store ETH here outside a transaction,
     * but we do want to be able to receive it in one call and return in another
     */
    receive() external payable {}

    /**
     * Call arbitrarty functions on arbitrary contracts.
     * WARNING! This is essentially a backdoor that allows for anything to happen. This isn't DeFi. This is a personal wallet.
     * The owner is allowed to call anything. This is helpful in case funds get somehow stuck.
     * The owner can authorize other contracts 
     */
    function execute(Action calldata action)
        public
        payable
        returns (bytes memory response)
    {
        // check auth
        if (msg.sender != owner()) {
            requireAuth(action.target, action.call_type, BytesLib.toBytes4(action.target_calldata));
        }

        // re-entrancy protection?

        require(
            Address.isContract(action.target),
            "ArgobytesProxy.execute !target"
        );

        // uncheckedDelegateCall is safe because we just checked that `target` is a contract
        if (action.call_type == ArgobytesAuthTypes.Call.DELEGATE) {
            response = AddressLib.uncheckedDelegateCall(
                action.target,
                action.target_calldata,
                "ArgobytesProxy.execute !delegatecall"
            );
        } else {
            response = AddressLib.uncheckedCall(
                action.target,
                action.forward_value,
                action.target_calldata,
                "ArgobytesProxy.execute !call"
            );
        }
    }

    // TODO: write example of using this to deploy a contract, then calling a function on it
    function executeMany(Action[] calldata actions)
        public
        payable
        returns (bytes[] memory responses)
    {
        responses = new bytes[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            responses[i] = execute(actions[i]);
        }

        return responses;
    }

    // TODO: EIP-165? EIP-721 receiver? those should probably be sent to the owner and then the owner approves this contract
    // TODO: gasless transactions?
}
