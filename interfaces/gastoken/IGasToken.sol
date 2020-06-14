// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.10;

abstract contract IGasToken {
    function free(uint256 value) public virtual returns (bool success);

    function freeUpTo(uint256 value) public virtual returns (uint256 freed);

    function freeFrom(address from, uint256 value)
        public
        virtual
        returns (bool success);

    function freeFromUpTo(address from, uint256 value)
        public
        virtual
        returns (uint256 freed);

    function mint(uint256 value) public virtual;

    function approve(address spender, uint256 value)
        public
        virtual
        returns (bool success);

    function balanceOf(address owner) public virtual returns (uint256 balance);
}
