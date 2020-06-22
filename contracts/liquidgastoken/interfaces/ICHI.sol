pragma solidity ^0.6.7;

import "@OpenZeppelin/token/ERC20/IERC20.sol";

interface ICHI is IERC20 {
    function free(uint256 value) external returns (uint256);

    function freeFrom(address from, uint256 value) external returns (uint256);

    function mint(uint256 value) external;
}
