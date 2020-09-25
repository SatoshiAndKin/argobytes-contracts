// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

interface IArgobytesAuthority {
    function canCall(
        address caller, address target, bytes4 sig
    ) external view returns (bool);
}

contract ArgobytesAuthority {

    // key is from `createKey`
    mapping (bytes => bool) authorizations;

    function createKey(
        address proxy, address sender, address target, bytes4 sig
    ) internal pure returns (bytes memory key) {
        // TODO: encode or encodePacked
        key = abi.encodePacked(proxy, sender, target, sig);
    }

    function canCall(
        address sender, address target, bytes4 sig
    ) external view returns (bool) {
        bytes memory key = createKey(msg.sender, sender, target, sig);

        return authorizations[key];
    }

    function allow(
        address[] calldata senders, address target, bytes4 sig
    ) external {
        bytes memory key;

        for (uint i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, sig);
            
            authorizations[key] = true;
        }
    }

    function deny(
        address[] calldata senders, address target, bytes4 sig
    ) external {
        bytes memory key;

        for (uint i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, senders[i], target, sig);

            delete authorizations[key];
        }
    }
}