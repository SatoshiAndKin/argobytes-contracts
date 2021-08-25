// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;
pragma abicoder v2;

import {IERC20} from "../erc20/IERC20.sol";

interface ICurveGaugeUnit is IERC20 {
    function deposit(uint256 amount) external returns (uint256);
}

interface IUnitVault {}

interface IUnitCDPManager {
    function join(
        address collateral,
        uint256 collateral_amount,
        uint256 usdp_amount
    ) external;
}
