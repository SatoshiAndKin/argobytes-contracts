// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface IArgobytesAuthority {
    function canCall(
        address caller,
        address target,
        bytes4 sig
    ) external view returns (bool);
}

/*
A shared registry for storing authorizations.

This is a seperate contract from the proxy so that there's no chance of delegatecalls changing storage.

The key includes msg.sender which should prevent most shinanengans.
*/
contract ArgobytesAuthority {
    // key is from `createKey`
    mapping(bytes => bool) authorizations;

    function createKey(
        address proxy,
        address sender,
        address target,
        bytes4 sig
    ) internal pure returns (bytes memory key) {
        // encodePacked should be safe because address and bytes4 are fixed size types
        key = abi.encodePacked(proxy, sender, target, sig);
    }

    // TODO: i can see some use-cases for not hard coding msg.sender here, but we don't need it now
    function canCall(
        address sender,
        address target,
        bytes4 sig
    ) external view returns (bool) {
        bytes memory key = createKey(msg.sender, sender, target, sig);

        return authorizations[key];
    }

    function allow(
        address[] calldata senders,
        address target,
        bytes4 sig
    ) external {
        bytes memory key;

        for (uint256 i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, sig);

            authorizations[key] = true;
        }
    }

    function deny(
        address[] calldata senders,
        address target,
        bytes4 sig
    ) external {
        bytes memory key;

        for (uint256 i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, sig);

            delete authorizations[key];
        }
    }
}
