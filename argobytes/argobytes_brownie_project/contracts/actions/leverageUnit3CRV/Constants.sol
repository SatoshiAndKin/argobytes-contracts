// SPDX-License-Identifier: MPL-2.0
// don't call this contract directly! use a proxy like DSProxy or ArgobytesProxy!
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
pragma solidity 0.8.7;
pragma abicoder v2;

import {IERC20} from "contracts/external/erc20/IERC20.sol";

import {ICurvePool} from "contracts/external/curvefi/ICurvePool.sol";
import {ICurveFeeDistribution} from "contracts/external/curvefi/ICurveFeeDistribution.sol";

import {ICurveGaugeUnit, IUnitVault, IUnitCDPManager} from "contracts/external/unit/Unit.sol";

abstract contract LeverageUnit3CRVConstants {
    // stablecoins
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant USDP = IERC20(0x1456688345527bE1f37E9e627DA0837D6f08C925);

    // curve
    IERC20 public constant THREE_CRV = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    ICurvePool public constant THREE_CRV_POOL = ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    // IERC20 public constant USDP_THREE_CRV = IERC20(0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6);
    ICurvePool public constant USDP_POOL = ICurvePool(0x42d7025938bEc20B69cBae5A77421082407f053A);

    ICurveFeeDistribution public constant THREE_CRV_FEE_DISTRIBUTION =
        ICurveFeeDistribution(0xA464e6DCda8AC41e03616F95f4BC98a13b8922Dc);

    // unit
    ICurveGaugeUnit public constant THREE_CRV_GAUGE_UNIT = ICurveGaugeUnit(0x4bfB2FA13097E5312B19585042FdbF3562dC8676);
    IUnitVault public constant UNIT_VAULT = IUnitVault(0xb1cFF81b9305166ff1EFc49A129ad2AfCd7BCf19);
    IUnitCDPManager public constant UNIT_CDP_MANAGER = IUnitCDPManager(0x0e13ab042eC5AB9Fc6F43979406088B9028F66fA);
}
