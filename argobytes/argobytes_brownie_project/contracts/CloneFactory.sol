// SPDX-License-Identifier: MPL-2.0
// TODO: needs a better name
pragma solidity 0.8.7;

import "@OpenZeppelin/proxy/Clones.sol";

/// @title Create clones of contracts and then call a function on them
contract CloneFactory {
    using Clones for address;

    event NewClone(address indexed clone, address indexed target, bytes32 salt);

    function cloneAndInit(address target, bytes32 salt, bytes calldata initData) external payable returns (address clone) {
        if (initData.length > 0) {
            salt = keccak256(abi.encodePacked(salt, initData));
        }

        clone = target.cloneDeterministic(salt);

        if (initData.length > 0) {
            (bool success, ) = clone.call(initData);
            require(success, "!init");
        }

        emit NewClone(clone, target, salt);
    }
}
