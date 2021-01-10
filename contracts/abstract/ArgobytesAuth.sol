// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {Strings2} from "contracts/library/Strings2.sol";
import {IArgobytesAuthority} from "contracts/ArgobytesAuthority.sol";

import {CloneOwner} from "./clonefactory/CloneOwner.sol";

contract ArgobytesAuthEvents {
    event AuthorityTransferred(
        address indexed previous_authority,
        address indexed new_authority
    );
}

abstract contract ArgobytesAuth is ArgobytesAuthEvents, CloneOwner {
    // note that this is state!
    // TODO: how can we be careful that a sneaky delegatecall doesn't change this
    IArgobytesAuthority public authority = IArgobytesAuthority(0);

    modifier auth {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        // TODO: GSN?
        // TODO: i can see cases where msg.data could be used, but i think thats more complex than we need
        requireAuth(address(this), msg.sig);
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
        // TODO: this reverts without a reason if authority isn't set and the caller is not the owner. is that okay?
        authorized =
            sender == owner() ||
            authority.canCall(sender, target, sig);
    }

    function requireAuth(address target, bytes4 sig) internal view {
        require(isAuthorized(msg.sender, target, sig), "ArgobytesAuth: 403");
    }

    function setAuthority(IArgobytesAuthority authority_) public auth {
        emit AuthorityTransferred(address(authority), address(authority_));
        authority = authority_;
    }
}
