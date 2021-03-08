// SPDX-License-Identifier: LGPL-3.0-or-later
// base class for clone targets
// contains a very powerful "execute" function! The owner is in full control!
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {Strings2} from "contracts/library/Strings2.sol";
import {IArgobytesAuthorizationRegistry} from "contracts/ArgobytesAuthorizationRegistry.sol";
import {IArgobytesFactory} from "contracts/ArgobytesFactory.sol";
import {Address2} from "contracts/library/Address2.sol";
import {Bytes2} from "contracts/library/Bytes2.sol";

import {ImmutablyOwnedClone} from "./ImmutablyOwnedClone.sol";

contract ArgobytesCloneEvents {
    event AuthorityTransferred(
        address indexed previous_authority,
        address indexed new_authority
    );
}

abstract contract ArgobytesClone is ArgobytesCloneEvents, ImmutablyOwnedClone {
    using Address for address;
    using Address2 for address;
    using Bytes2 for bytes;

    // note that this is state!
    // TODO: how can we be careful that a sneaky delegatecall doesn't change this. maybe store it in a custom slot?
    IArgobytesAuthorizationRegistry public authority;

    /*
    Instead of deploying this contract, most users should setup a proxy to this contract that uses delegatecall

    If you do want to use this contract directly, you need to be sure to append the owner's address to the end of the bytecode!
    */
    constructor() {}

    /*
     * we shouldn't store ETH here outside a transaction,
     * but we do want to be able to receive it in one call and return in another
     */
    receive() external payable {}

    modifier auth {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        // TODO: GSN?
        // TODO: i can see cases where msg.data could be used, but i think thats more complex than we need
        if (msg.sender != owner()) {
            requireAuth(address(this), msg.sig);
        }
        _;
    }

    /*
    Check if the `sender` is authorized to delegatecall the `sig` on a `target` contract.

    This should allow for some pretty powerful delegation. With great power comes great responsibility!

    Other contracts I've seen that work similarly to our auth allow `sender == address(this)`
    That makes me uncomfortable. Essentially no one is checking their calldata.
    A malicious site could slip a setAuthority call into the middle of some other set of actions.
    */
    function isAuthorized(
        address sender,
        address target,
        bytes4 sig
    ) internal view returns (bool authorized) {
        // this reverts without a reason if authority isn't set and the caller is not the owner. is that okay?
        // we could check != address(0) and do authority.canCall in a try/catch, but that costs more gas
        authorized = authority.canCall(sender, target, sig);
    }

    function requireAuth(address target, bytes4 sig) internal view {
        require(isAuthorized(msg.sender, target, sig), "ArgobytesAuth: 403");
    }

    function setAuthority(IArgobytesAuthorizationRegistry authority_) public auth {
        emit AuthorityTransferred(address(authority), address(authority_));
        authority = authority_;
    }

    /**
     * Call arbitrarty functions on arbitrary contracts.
     * WARNING! This is essentially a backdoor that allows for anything to happen. This isn't DeFi. This is a personal wallet.
     * The owner is allowed to call anything. This is helpful in case funds get somehow stuck.
     * The owner can authorize other contracts 
     */
    function execute(address target, bytes memory target_calldata)
        public
        payable
        returns (bytes memory response)
    {
        if (msg.sender != owner()) {
            requireAuth(target, target_calldata.toBytes4());
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
        bytes memory target_code,
        bytes memory target_calldata
    ) public payable returns (address target, bytes memory response) {
        // most cases will probably want an empty salt and a self-destructing target_code
        // adding a salt adds to the calldata. that negates some of the savings from 0 bytes in target
        target = factory.checkedCreateContract(target_salt, target_code);

        if (msg.sender != owner()) {
            requireAuth(target, target_calldata.toBytes4());
        }

        // uncheckedDelegateCall is safe because we just used `existingOrCreate2`
        response = target.uncheckedDelegateCall(
            target_calldata,
            "ArgobytesProxy.createContractAndExecute failed"
        );
    }

    // TODO: EIP-165? EIP-721 receiver? those should probably be sent to the owner and then the owner approves this contract
    // TODO: gasless transactions?
}
