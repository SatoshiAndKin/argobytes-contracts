// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {DyDxTypes} from "./DyDxTypes.sol";

interface ISoloMargin {
    function operate(
        DyDxTypes.AccountInfo[] memory accounts,
        DyDxTypes.ActionArgs[] memory actions
    ) external;

    function getMarketIsClosing(uint256 marketId) external view returns (bool);

    function getMarketTokenAddress(uint256 marketId)
        external
        view
        returns (address);
}
