// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.4;

import {CompleteIERC20} from "contracts/external/erc20/IERC20.sol";

interface IYVault is CompleteIERC20 {
    function deposit(uint256 amount) external;

    function getPricePerFullShare() external returns (uint256);

    function withdraw(uint256 amount) external;
}
