// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {ArgobytesAuthority} from "contracts/ArgobytesAuthority.sol";

import {ActionTypes} from "./ActionTypes.sol";
import {ImmutablyOwned} from "./ImmutablyOwned.sol";

error AccessDenied();

/// @title Access control with an immutable owner
/// @dev clone targets for ArgobytesFactory19 need to use this (or something like it)
abstract contract ArgobytesAuth is ActionTypes, ImmutablyOwned {
    // TODO: diamond storage?
    ArgobytesAuthority authority;

    event AuthorityTransferred(address indexed previous_authority, address indexed new_authority);

    /// @dev standard auth check
    modifier auth(CallType call_type) {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        if (msg.sender != owner()) {
            requireAuth(msg.sender, address(this), call_type, msg.sig);
        }
        _;
    }

    /// @notice Check if the `sender` is authorized to delegatecall the `sig` on a `target` contract.
    /** @dev
    This should allow for some pretty powerful delegation. With great power comes great responsibility!

    Other contracts I've seen that work similarly to our auth allow `sender == address(this)`
    That makes me uncomfortable. Essentially no one is checking their calldata.
    A malicious site could slip a setAuthority call into the middle of some other set of actions.

    I can see cases where msg.data could be used, but i think thats more complex than we need
    */
    function isAuthorized(
        address sender,
        CallType call_type,
        address target,
        bytes4 sig
    ) internal view returns (bool) {
        if (address(authority) == address(0)) {
            return false;
        }
        return authority.canCall(sender, target, call_type, sig);
    }

    /// @notice revert if authorization is denied
    function requireAuth(
        address sender,
        address target,
        CallType call_type,
        bytes4 sig
    ) internal view {
        if (!isAuthorized(sender, call_type, target, sig)) revert AccessDenied();
    }

    /// @notice Set the contract used for checking authentication
    function setAuthority(ArgobytesAuthority new_authority) public auth(CallType.ADMIN) {
        emit AuthorityTransferred(address(authority), address(new_authority));

        authority = new_authority;
    }
}
