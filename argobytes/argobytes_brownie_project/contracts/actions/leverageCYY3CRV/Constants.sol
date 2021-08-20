// SPDX-License-Identifier: MPL-2.0
// don't call this contract directly! use a proxy like DSProxy or ArgobytesProxy!
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
pragma solidity 0.8.7;
pragma abicoder v2;

import {IERC20} from "contracts/external/erc20/IERC20.sol";

import {ICurvePool} from "contracts/external/curvefi/ICurvePool.sol";
import {ICurveFeeDistribution} from "contracts/external/curvefi/ICurveFeeDistribution.sol";

import {ICERC20} from "contracts/external/cream/ICERC20.sol";
import {IComptroller} from "contracts/external/cream/IComptroller.sol";

import {IYVault} from "contracts/external/yearn/IYVault.sol";

abstract contract LeverageCYY3CRVConstants {
    // stablecoins
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    // curve
    IERC20 public constant THREE_CRV = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    ICurvePool public constant THREE_CRV_POOL = ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurveFeeDistribution public constant THREE_CRV_FEE_DISTRIBUTION =
        ICurveFeeDistribution(0xA464e6DCda8AC41e03616F95f4BC98a13b8922Dc);

    // cream
    IComptroller public constant CREAM = IComptroller(0xAB1c342C7bf5Ec5F02ADEA1c2270670bCa144CbB);
    ICERC20 public constant CY_Y_THREE_CRV = ICERC20(0x7589C9E17BCFcE1Ccaa1f921196FDa177F0207Fc);
    ICERC20 public constant CY_DAI = ICERC20(0x8e595470Ed749b85C6F7669de83EAe304C2ec68F);

    // yearn
    IYVault public constant Y_THREE_CRV = IYVault(0x9cA85572E6A3EbF24dEDd195623F188735A5179f);
}
