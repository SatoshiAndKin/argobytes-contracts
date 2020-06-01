// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.8;


interface IProxy {
    function target() external view returns (address);
}
