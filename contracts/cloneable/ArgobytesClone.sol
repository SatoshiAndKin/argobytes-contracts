// SPDX-License-Identifier: LGPL-3.0-or-later
// base class for clone targets
// contains a very powerful "execute" function! The owner is in full control!
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {Strings2} from "contracts/library/Strings2.sol";
import {IArgobytesFactory} from "contracts/ArgobytesFactory.sol";
import {Address2} from "contracts/library/Address2.sol";
import {Bytes2} from "contracts/library/Bytes2.sol";

import {ArgobytesAuth} from "contracts/abstract/ArgobytesAuth.sol";

// TODO: should this be able to receive a flash loan?
abstract contract ArgobytesClone is ArgobytesAuth {
    using Address for address;
    using Address2 for address;
    using Bytes2 for bytes;

    struct Action {
        address target;
        ArgobytesAuth.CallType call_type;
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
            requireAuth(action.target, action.call_type, action.target_calldata.toBytes4());
        }

        require(
            Address.isContract(action.target),
            "ArgobytesProxy.execute !target"
        );

        // uncheckedDelegateCall is safe because we just checked that `target` is a contract
        if (action.call_type == ArgobytesAuth.CallType.DELEGATE) {
            response = Address2.uncheckedDelegateCall(
                action.target,
                action.target_calldata,
                "ArgobytesProxy.execute !delegatecall"
            );
        } else {
            response = Address2.uncheckedCall(
                action.target,
                action.target_calldata,
                "ArgobytesProxy.execute !call"
            );
        }
    }

    // TODO: write example of using this to deploy a contract, then call a function on it
    function executeMany(Action[] calldata actions)
        public
        payable
        returns (bytes[] memory responses)
    {
        responses = bytes[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            responses[i] = this.execute(actions[i]);
        }
    }

    // TODO: EIP-165? EIP-721 receiver? those should probably be sent to the owner and then the owner approves this contract
    // TODO: gasless transactions?
}
