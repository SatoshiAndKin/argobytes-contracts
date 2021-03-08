// SPDX-License-Identifier: LGPL-3.0-or-later
// helper for flash loaning DAI
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
pragma solidity 0.7.6;
pragma abicoder v2;

import {Constants} from "./Constants.sol";

import {DyDxTypes, IDyDxSoloMargin} from "contracts/external/dydx/IDyDxSoloMargin.sol";
import {IDyDxCallee} from "contracts/external/dydx/IDyDxCallee.sol";

abstract contract DyDxCallee is Constants, IDyDxCallee {

    function _flashloanDAI(uint256 amount, bytes memory data) internal {
        // setup the flash loan account
        DyDxTypes.AccountInfo[] memory accountInfos = new DyDxTypes.AccountInfo[](1);
        accountInfos[0] = DyDxTypes.AccountInfo({
            owner: address(this),
            number: 0
        });

        // setup the flash loan actions
        DyDxTypes.ActionArgs[] memory operations = new DyDxTypes.ActionArgs[](3);

        // 1. borrow some token
        // set borrow_id to match https://legacy-docs.dydx.exchange/#solo-markets
        // 0 = WETH, 1 = SAI, 2 = USDC, 3 = DAI
        operations[0] = DyDxTypes.ActionArgs({
            actionType: DyDxTypes.ActionType.Withdraw,
            accountId: 0,
            amount: DyDxTypes.AssetAmount({
                sign: false,
                denomination: DyDxTypes.AssetDenomination.Wei,
                ref: DyDxTypes.AssetReference.Delta,
                value: amount
            }),
            primaryMarketId: 3,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });

        // include the fee in amount
        amount += 1;

        // 2. call our function
        operations[1] = DyDxTypes.ActionArgs({
            actionType: DyDxTypes.ActionType.Call,
            accountId: 0,
            amount: DyDxTypes.AssetAmount({
                sign: false,
                denomination: DyDxTypes.AssetDenomination.Wei,
                ref: DyDxTypes.AssetReference.Delta,
                value: 0
            }),
            primaryMarketId: 0,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: abi.encode(amount, data)
        });

        // approve the return of the flash loan
        DAI.approve(address(DYDX_SOLO_MARGIN), amount);

        // 3. repay the flash loan
        operations[2] = DyDxTypes.ActionArgs({
            actionType: DyDxTypes.ActionType.Deposit,
            accountId: 0,
            amount: DyDxTypes.AssetAmount({
                sign: true,
                denomination: DyDxTypes.AssetDenomination.Wei,
                ref: DyDxTypes.AssetReference.Delta,
                value: amount
            }),
            primaryMarketId: 3,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });

        // do the flash loan
        DYDX_SOLO_MARGIN.operate(accountInfos, operations);
    }
}
