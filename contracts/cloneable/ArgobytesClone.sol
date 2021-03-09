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
    function execute(address target, ArgobytesAuth.CallType call_type, bytes memory target_calldata)
        public
        payable
        returns (bytes memory response)
    {
        // check auth
        if (msg.sender != owner()) {
            requireAuth(target, call_type, target_calldata.toBytes4());
        }

        require(
            Address.isContract(target),
            "ArgobytesProxy.execute BAD_TARGET"
        );

        // uncheckedDelegateCall is safe because we just checked that `target` is a contract
        response = target.uncheckedDelegateCall(
            target_calldata,
            "ArgobytesProxy.execute failed"
        );
    }

    /**
     * Deploy a contract and then call arbitrary functions on it.
     * WARNING! This is essentially a backdoor that allows for anything to happen. This isn't DeFi. This is a personal wallet.
     * The owner is allowed to call anything. This is helpful in case funds get somehow stuck.
     * Before even deploying the contract, the owner can authorize other senders to call any functions on it.
     * Then the sender can deploy it once it is needed. This should save on unnecessary deployments.
     */
    function createContractAndExecute(
        IArgobytesFactory factory,
        bytes32 target_salt,
        ArgobytesAuth.CallType call_type,
        bytes memory target_code,
        bytes memory target_calldata
    ) public payable returns (address target, bytes memory response) {
        // most cases will probably want an empty salt and a self-destructing target_code
        // adding a salt adds to the calldata. that negates some of the savings from 0 bytes in target
        target = factory.checkedCreateContract(target_salt, target_code);

        if (msg.sender != owner()) {
            requireAuth(target, call_type, target_calldata.toBytes4());
        }

        // uncheckedDelegateCall is safe because we just used `existingOrCreate2`
        if (call_type == ArgobytesAuth.CallType.DELEGATE) {
            response = Address2.uncheckedDelegateCall(
                target,
                target_calldata,
                "ArgobytesProxy.createContractAndExecute failed"
            );
        } else {
            response = Address2.uncheckedCall(
                target,
                target_calldata,
                "ArgobytesProxy.createContractAndExecute failed"
            );
        }
    }

    // TODO: EIP-165? EIP-721 receiver? those should probably be sent to the owner and then the owner approves this contract
    // TODO: gasless transactions?
}
