// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;
pragma abicoder v2;

import {IERC20} from "contracts/external/erc20/IERC20.sol";

import {ICurvePool} from "contracts/external/curvefi/ICurvePool.sol";

import {ICERC20} from "contracts/external/cream/ICERC20.sol";
import {IComptroller} from "contracts/external/cream/IComptroller.sol";

import {IAaveVariableDebtToken} from "contracts/external/aave/IAaveVariableDebtToken.sol";
import {IAToken} from "contracts/external/aave/IAToken.sol";

abstract contract LeverageAaveConstants {
    // stablecoins
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    // curve
    IERC20 public constant THREE_CRV = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    ICurvePool public constant THREE_CRV_POOL = ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    // aave
    IAToken public constant AAVE_USDC = IAToken(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    IAaveVariableDebtToken public constant AAVE_USDT_DEBT = IAaveVariableDebtToken(0x531842cEbbdD378f8ee36D171d6cC9C4fcf475Ec)
}
