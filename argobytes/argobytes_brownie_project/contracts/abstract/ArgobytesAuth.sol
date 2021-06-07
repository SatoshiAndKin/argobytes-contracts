// SPDX-License-Identifier: MPL-2.0
// base class for clone targets
// contains a very powerful "execute" function! The owner is in full control!
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {ArgobytesAuthority} from "contracts/ArgobytesAuthority.sol";
import {AddressLib} from "contracts/library/AddressLib.sol";
import {BytesLib} from "contracts/library/BytesLib.sol";

import {ActionTypes} from "./ActionTypes.sol";
import {ImmutablyOwned} from "./ImmutablyOwned.sol";

error AccessDenied();

/// @title Access control with an immutable owner
abstract contract ArgobytesAuth is ImmutablyOwned {
    /// @dev diamond storage
    /// @notice be sure that a sneaky delegatecall doesn't change this!
    struct ArgobytesAuthStorage {
        ArgobytesAuthority authority;
    }

    /// @dev diamond storage
    bytes32 constant ARGOBYTES_AUTH_POSITION = keccak256("argobytes.storage.ArgobytesAuth");

    /// @dev diamond storage
    function argobytesAuthStorage() internal pure returns (ArgobytesAuthStorage storage s) {
        bytes32 position = ARGOBYTES_AUTH_POSITION;
        assembly {
            s.slot := position
        }
    }

    event AuthorityTransferred(address indexed previous_authority, address indexed new_authority);

    modifier auth(ActionTypes.Call call_type) {
        // do auth first. that is safest
        // theres some cases where it may be possible to do the auth check last, but it is too risky for me
        if (msg.sender != owner()) {
            requireAuth(address(this), call_type, msg.sig);
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
        ActionTypes.Call call_type,
        address target,
        bytes4 sig
    ) internal view returns (bool authorized) {
        ArgobytesAuthStorage storage s = argobytesAuthStorage();

        // TODO: this reverts without a reason if authority isn't set and the caller is not the owner. is that okay?
        // we could check != address(0) and do authority.canCall in a try/catch, but that costs more gas
        authorized = s.authority.canCall(sender, target, call_type, sig);
    }

    /// @notice revert if authorization is denied
    function requireAuth(
        address target,
        ActionTypes.Call call_type,
        bytes4 sig
    ) internal view {
        if (!isAuthorized(msg.sender, call_type, target, sig)) revert AccessDenied();
    }

    /// @notice Set the contract used for checking authentication
    function setAuthority(ArgobytesAuthority new_authority) public auth(ActionTypes.Call.ADMIN) {
        ArgobytesAuthStorage storage s = argobytesAuthStorage();

        emit AuthorityTransferred(address(s.authority), address(new_authority));

        s.authority = new_authority;
    }
}
