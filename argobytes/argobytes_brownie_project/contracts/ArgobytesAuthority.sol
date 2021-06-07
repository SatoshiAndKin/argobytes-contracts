// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.4;

import {ActionTypes} from "contracts/abstract/ActionTypes.sol";

/// @title A shared registry for storing authorizations
/// @dev This is a seperate contract from the proxy so that there's no chance of delegatecalls changing storage
contract ArgobytesAuthority {
    /// @dev key is from `createKey`
    mapping(bytes => bool) authorizations;

    /// @dev the key includes msg.sender which should prevent most shinanengans.
    function createKey(
        address proxy,
        address sender,
        address target,
        ActionTypes.Call call_type,
        bytes4 sig
    ) internal pure returns (bytes memory key) {
        // encodePacked should be safe because address and enums and bytes4 are fixed size types
        // no need to hash this here. mappings already hash their keys
        key = abi.encodePacked(proxy, sender, target, call_type, sig);
    }

    /// @notice Check that sender is allowed to call the given function
    // TODO: i can see some use-cases for not hard coding msg.sender here, but we don't need it now
    function canCall(
        address sender,
        address target,
        ActionTypes.Call call_type,
        bytes4 sig
    ) external view returns (bool) {
        bytes memory key = createKey(msg.sender, sender, target, call_type, sig);

        return authorizations[key];
    }

    /// @notice Allow an address to call a function
    /// @notice SECURITY! If `target` is upgradable, the function at `sig` could be changed and a `sender` may be able to do something malicious!
    function allow(
        address[] calldata senders,
        address target,
        ActionTypes.Call call_type,
        bytes4 sig
    ) external {
        bytes memory key;

        for (uint256 i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, call_type, sig);

            authorizations[key] = true;
        }
    }

    function deny(
        address[] calldata senders,
        address target,
        ActionTypes.Call call_type,
        bytes4 sig
    ) external {
        bytes memory key;

        for (uint256 i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, call_type, sig);

            delete authorizations[key];
        }
    }
}
