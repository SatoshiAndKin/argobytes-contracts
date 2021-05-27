// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.4;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

interface CompleteIERC20 is IERC20 {
    // OZ is missing getter functions for the state variables
    function decimals() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}


interface UnindexedIERC20 {
    function decimals() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);

    // transfer event without indexes
    event Transfer(address from, address to, uint256 value);
}
 