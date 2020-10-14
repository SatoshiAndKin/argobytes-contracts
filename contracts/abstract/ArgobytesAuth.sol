// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Strings2} from "contracts/library/Strings2.sol";

import {IArgobytesAuthority} from "contracts/ArgobytesAuthority.sol";

contract ArgobytesAuthEvents {
    event AuthorityTransferred(
        address indexed previous_authority,
        address indexed new_authority
    );
}

abstract contract ArgobytesAuth is ArgobytesAuthEvents {
    using Strings2 for address;

    bool internal initialized = false;
    IArgobytesAuthority public authority;

    // TODO: think more about this. how does OZ do initialization functions?
    function initArgobytesAuth(IArgobytesAuthority authority_) internal {
        require(initialized == false, "already initialized");

        initialized = true;

        authority = authority_;
    }

    modifier auth {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        requireAuth(address(this), msg.sig);
        _;
    }

    // pull the owner out of the contract code
    // since calls to this are always delegate calls, this will be the code of the caller
    // TODO: an immutable keyword would be nice here, but because of how we make the proxy, we don't have a constructor
    function owner() public view returns (address) {
        address thisAddress = address(this);
        bytes memory thisCode;

        assembly {
            // retrieve the size of the code
            let size := extcodesize(thisAddress)
            // allocate output byte array
            thisCode := mload(0x40)
            // setup enough space for the address
            mstore(thisCode, 32)
            // get the last 20 (32-12; 0x14) bytes of code minus padding (which should be our address)
            extcodecopy(
                thisAddress,
                add(thisCode, 0x20),
                sub(size, 32),
                sub(size, 12)
            )
        }

        return abi.decode(thisCode, (address));
    }

    function isAuthorized(
        address sender,
        address target,
        bytes4 sig
    ) internal view returns (bool) {
        // if (sender == owner()) {
        //     // the owner always has access to all functions
        //     return true;
        // } else if (authority == IArgobytesAuthority(0)) {
        //     // the contract does not have an authorization contract to check
        //     // TODO: do we even need this check? authority.canCall will revert if authority doesn't exist
        //     return false;
        // } else {
        //     // use a smart contract to check auth
        //     // TODO? do we want to split canCall and canDelegateCall? this is actually used for delegates
        //     return authority.canCall(sender, target, sig);
        // }
        return sender == owner() || authority.canCall(sender, target, sig);
    }

    function requireAuth(address target, bytes4 sig) internal view {
        require(isAuthorized(msg.sender, target, sig), "ArgobytesAuth: 403");
    }

    function setAuthority(IArgobytesAuthority authority_) public auth {
        emit AuthorityTransferred(address(authority), address(authority_));
        authority = authority_;
    }
}
