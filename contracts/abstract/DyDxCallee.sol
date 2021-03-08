// SPDX-License-Identifier: LGPL-3.0-or-later
// helper for flash loaning DAI
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
// TODO: move this to contracts/abstract and use it in other actionss
pragma solidity 0.7.6;
pragma abicoder v2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {DyDxTypes, IDyDxSoloMargin} from "contracts/external/dydx/IDyDxSoloMargin.sol";
import {IDyDxCallee} from "contracts/external/dydx/IDyDxCallee.sol";

abstract contract DyDxCallee is IDyDxCallee {

    IDyDxSoloMargin public constant DYDX_SOLO_MARGIN = IDyDxSoloMargin(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);

    bool private _pending_flashloan = false;

    modifier authFlashLoan() {
        require(_pending_flashloan, "!pending_flashloan");
        _;
    }

    // i was going to have an enum for borrow_token/borrow_id, but what if they add new ones in the future?

    function _DyDxFlashloan(uint256 borrow_id, address borrow_token, uint256 amount, address target, bytes memory data) internal {
        // require(!_pending_flashloan, "pending_flashloan");   // TODO: do we need this check?

        _pending_flashloan = true;

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
            primaryMarketId: borrow_id,
            secondaryMarketId: 0,
            otherAddress: target,
            otherAccountId: 0,
            data: ""
        });

        // include the fee in amount
        // it might be 1 or 2 depending on the borrow_id, but assuming 2 is cheap enough
        amount += 2;

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
            otherAddress: target,
            otherAccountId: 0,
            data: abi.encode(amount, data)
        });

        // approve the return of the flash loan
        // TODO: maybe target should be the one doing the approve
        IERC20(borrow_token).approve(address(DYDX_SOLO_MARGIN), amount);

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
            primaryMarketId: borrow_id,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });

        // do the flash loan
        DYDX_SOLO_MARGIN.operate(accountInfos, operations);

        _pending_flashloan = false;
    }
}
