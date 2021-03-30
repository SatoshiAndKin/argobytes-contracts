// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.3;

import {IERC20 as OZ_IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

interface IERC20 is OZ_IERC20 {
    // OZ is missing getter functions for the state variables
    function decimals() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}
