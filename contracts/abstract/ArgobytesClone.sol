// SPDX-License-Identifier: LGPL-3.0-or-later
// base class for clone targets
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Strings2} from "contracts/library/Strings2.sol";
import {IArgobytesAuthorizationRegistry} from "contracts/ArgobytesAuthorizationRegistry.sol";

import {ImmutablyOwnedClone} from "./ImmutablyOwnedClone.sol";

contract ArgobytesCloneEvents {
    event AuthorityTransferred(
        address indexed previous_authority,
        address indexed new_authority
    );
}

abstract contract ArgobytesClone is ArgobytesCloneEvents, ImmutablyOwnedClone {
    // note that this is state!
    // TODO: how can we be careful that a sneaky delegatecall doesn't change this. maybe store it in a custom slot?
    IArgobytesAuthorizationRegistry public authority;

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

    // TODO: have a function that 
}
