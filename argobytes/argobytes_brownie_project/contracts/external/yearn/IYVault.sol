// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

import {IERC20} from "contracts/external/erc20/IERC20.sol";

interface IYVault is IERC20 {
    function deposit(uint256 amount) external;

    function getPricePerFullShare() external returns (uint256);

    function withdraw(uint256 amount) external;
}
