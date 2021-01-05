// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.4;

interface IProxy {
    function target() external view returns (address);
}
