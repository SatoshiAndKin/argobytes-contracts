// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {IArgobytesAuthority} from "contracts/ArgobytesAuthority.sol";

import {Ownable2} from "./Ownable2.sol";

abstract contract ArgobytesAuth is Ownable2 {
    IArgobytesAuthority public authority;

    event AuthorityTransferred(address indexed previous_authority, address indexed new_authority);

    constructor(address owner, IArgobytesAuthority authority_) Ownable2(owner) {
        authority = authority_;
    }

    modifier auth(bool delegate) {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        requireAuth(delegate, address(this), msg.sig);
        _;
    }

    function isAuthorized(address sender, bool delegate, address target, bytes4 sig) internal view returns (bool) {
        if (sender == owner()) {
            // the owner always has access to all functions
            return true;
        } else if (authority == IArgobytesAuthority(0)) {
            // the contract does not have an authorization contract to check
            return false;
        } else {
            // use a smart contract to check auth
            // TODO? do we want to split canCall and canDelegateCall? this is actually used for delegates
            return authority.canCall(delegate, sender, target, sig);
        }
    }

    function requireAuth(bool delegate, address target, bytes4 sig) internal view {
        require(isAuthorized(msg.sender, delegate, target, sig), "ArgobytesAuth: 403");
    }

    function setAuthority(IArgobytesAuthority authority_)
        public
        auth(false)
    {
        emit AuthorityTransferred(address(authority), address(authority_));
        authority = authority_;
    }
}
