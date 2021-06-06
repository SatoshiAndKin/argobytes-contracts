// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.4;

import {IERC20Metadata} from "contracts/external/erc20/IERC20.sol";

interface IYVault is IERC20Metadata {
    function deposit(uint256 amount) external;

    function getPricePerFullShare() external returns (uint256);

    function withdraw(uint256 amount) external;
}
