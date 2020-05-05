pragma solidity 0.6.4;

abstract contract IGasToken {
    function free(uint256 value) virtual public returns (bool success);
    function freeUpTo(uint256 value) virtual public returns (uint256 freed);
    function freeFrom(address from, uint256 value) virtual public returns (bool success);
    function freeFromUpTo(address from, uint256 value) virtual public returns (uint256 freed);

    function mint(uint256 value) virtual public;

    function approve(address spender, uint256 value) virtual public returns (bool success);
    function balanceOf(address owner) virtual public returns (uint256 balance);
}
