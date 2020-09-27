// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

interface IArgobytesAuthority {
    function canCall(
        bool delegte, address caller, address target, bytes4 sig
    ) external view returns (bool);
}

contract ArgobytesAuthority {

    // key is from `createKey`
    mapping (bytes => bool) authorizations;

    function createKey(
        address proxy, bool delegate, address sender, address target, bytes4 sig
    ) internal pure returns (bytes memory key) {
        // encodePacked should be safe because address and bytes4 are fixed size types
        key = abi.encodePacked(proxy, delegate, sender, target, sig);
    }

    function canCall(
        bool delegate, address sender, address target, bytes4 sig
    ) external view returns (bool) {
        bytes memory key = createKey(msg.sender, delegate, sender, target, sig);

        return authorizations[key];
    }

    function allow(
        bool delegate, address[] calldata senders, address target, bytes4 sig
    ) external {
        bytes memory key;

        for (uint i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, delegate, senders[i], target, sig);
            
            authorizations[key] = true;
        }
    }

    function deny(
        bool delegate, address[] calldata senders, address target, bytes4 sig
    ) external {
        bytes memory key;

        for (uint i = 0; i < senders.length; i++) {
            key = createKey(msg.sender, delegate, senders[i], target, sig);

            delete authorizations[key];
        }
    }
}