// SPDX-License-Identifier: LGPL-3.0-or-later
/*
A shared registry for storing authorizations.

This is a seperate contract from the proxy so that there's no chance of delegatecalls changing storage.

The key includes msg.sender which should prevent most shinanengans.
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {ArgobytesAuthTypes} from "contracts/abstract/ArgobytesAuth.sol";


interface IArgobytesAuthority {
    function canCall(
        address caller,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) external view returns (bool);

    function allow(
        address[] calldata senders,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) external;

    function deny(
        address[] calldata senders,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) external;
}

contract ArgobytesAuthority is IArgobytesAuthority{
    // key is from `createKey`
    mapping(bytes => bool) authorizations;

    function createKey(
        address proxy,
        address sender,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) internal pure returns (bytes memory key) {
        // encodePacked should be safe because address and enums and bytes4 are fixed size types
        // no need to hash this here. mappings already hash their keys
        key = abi.encodePacked(proxy, sender, target, call_type, sig);
    }

    // TODO: i can see some use-cases for not hard coding msg.sender here, but we don't need it now
    function canCall(
        address sender,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) external override view returns (bool) {
        bytes memory key = createKey(msg.sender, sender, target, call_type, sig);

        return authorizations[key];
    }

    // SECURITY! If `target` is upgradable, the function at `sig` could be changed and a `sender` may be able to do something malicious!
    function allow(
        address[] calldata senders,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) external override {
        bytes memory key;

        for (uint256 i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, call_type, sig);

            authorizations[key] = true;
        }
    }

    function deny(
        address[] calldata senders,
        address target,
        ArgobytesAuthTypes.Call call_type,
        bytes4 sig
    ) external override {
        bytes memory key;

        for (uint256 i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, call_type, sig);

            delete authorizations[key];
        }
    }
}
