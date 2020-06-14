// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.10;

interface IProxy {
    function target() external view returns (address);
}
