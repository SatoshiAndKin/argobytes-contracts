// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

interface IArgobytesAuthority {
    function canCall(
        address caller, address target, bytes4 sig
    ) external view returns (bool);
}

contract ArgobytesAuthority {

    // TODO: think more about this
    // msg.sender => caller => target => sig => true
    mapping (address => mapping (address => mapping (address => mapping (bytes4 => bool)))) authorizations;

    function canCall(
        address caller, address target, bytes4 sig
    ) external view returns (bool) {
        return authorizations[msg.sender][caller][target][sig];
    }

    function allow(
        address[] calldata callers, address target, bytes4 sig
    ) external {
        for (uint i = 0; i < callers.length; i++) {
            authorizations[msg.sender][callers[i]][target][sig] = true;
        }
    }

    function deny(
        address[] calldata callers, address target, bytes4 sig
    ) external {
        for (uint i = 0; i < callers.length; i++) {
            delete authorizations[msg.sender][callers[i]][target][sig];
        }
    }
}