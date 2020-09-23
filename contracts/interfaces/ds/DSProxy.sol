// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.0;

interface DSProxyFactory {
    event Created(address indexed sender, address indexed owner, address proxy, address cache);

    function build() external returns (address payable proxy);
    function build(address owner) external returns (address payable proxy);
}
