// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.4;


interface IENS {
    function resolver(bytes32 node) external returns (IResolver);
}

interface IResolver {
    function addr(bytes32 node) external returns (address);
}
