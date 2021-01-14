// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.6;

interface IProxy {
    function target() external view returns (address);
}
