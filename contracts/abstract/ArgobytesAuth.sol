// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IArgobytesAuthority} from "contracts/ArgobytesAuthority.sol";

import {Ownable2} from "./Ownable2.sol";

abstract contract ArgobytesAuth is Ownable2 {
    IArgobytesAuthority public authority;

    event AuthorityTransferred(address indexed previous_authority, address indexed new_authority);

    constructor(address owner, IArgobytesAuthority authority_) Ownable2(owner) {
        authority = authority_;
    }

    modifier auth() {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        requireAuth(address(this), msg.sig);
        _;
    }

    function requireAuth(address target, bytes4 sig) internal view {
        require(isAuthorized(msg.sender, target, sig), "ArgobytesAuth: 403");
    }

    function isAuthorized(address sender, address target, bytes4 sig) internal view returns (bool) {
        if (sender == owner()) {
            // the owner always has access to all functions
            return true;
        } else if (authority == IArgobytesAuthority(0)) {
            // the contract does not have an authorization contract to check
            return false;
        } else {
            // use a smart contract to check auth
            // TODO? do we want to split canCall and canDelegateCall? this is actually used for delegates
            return authority.canCall(sender, target, sig);
        }
    }

    function setAuthority(IArgobytesAuthority authority_)
        public
        auth
    {
        emit AuthorityTransferred(address(authority), address(authority_));
        authority = authority_;
    }
}
