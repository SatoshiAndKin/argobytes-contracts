// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.10;

interface IGasToken {
    function free(uint256 value) external returns (bool success);

    function freeUpTo(uint256 value) external returns (uint256 freed);

    function freeFrom(address from, uint256 value)
        external
        returns (bool success);

    function freeFromUpTo(address from, uint256 value)
        external
        returns (uint256 freed);

    function mint(uint256 value) external;

    function approve(address spender, uint256 value)
        external
        returns (bool success);

    function balanceOf(address owner) external returns (uint256 balance);

    function transfer(address to, uint256 amount)
        external
        returns (bool success);
}
