// SPDX-License-Identifier: MPL-2.0
// TODO: needs a better name
pragma solidity 0.8.7;

import "@OpenZeppelin/proxy/Clones.sol";

/// @title Create clones of contracts and then call a function on them
contract CloneFactory {
    using Clones for address;

    event NewClone(address indexed clone, address indexed target, bytes32 salt);

    function cloneTarget(address target, bytes32 salt) external payable returns (address clone) {
        clone = target.cloneDeterministic(salt);
        emit NewClone(clone, target, salt);
    }
}
