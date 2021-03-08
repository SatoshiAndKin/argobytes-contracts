// SPDX-License-Identifier: LGPL-3.0-or-later
// don't call this contract directly! use a proxy like DSProxy or ArgobytesProxy!
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
pragma solidity 0.7.6;
pragma abicoder v2;

import {Constants} from "./Constants.sol";
import {DyDxCallee, DyDxTypes} from "./DyDxCallee.sol";

import {ArgobytesClone} from "contracts/abstract/ArgobytesClone.sol";


contract ExitCYY3CRV is ArgobytesClone, Constants, DyDxCallee {

    bool _pending_flashloan = false;

    struct ExitLoanData {
        uint256 min_remove_liquidity_dai;
        uint256 tip_dai;
        address tip_address;
        // true to exit for msg.sender. false to exit for this contract
        bool exit_sender;
    }

    /* Users should delegatecall this function through a proxy. */
    function exit(
        ExitLoanData calldata data
    ) external auth payable {
        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            (bool success, ) = data.tip_address.call{value: msg.value}("");
            require(success, "!tip");
        }

        // https://compound.finance/docs#protocol-math
        uint256 dai_borrow_balance = CY_DAI.exchangeRateCurrent();

        if (data.exit_sender) {
            dai_borrow_balance *= CY_DAI.borrowBalanceCurrent(msg.sender);
        } else {
            dai_borrow_balance *= CY_DAI.borrowBalanceCurrent(address(this));
        }

        dai_borrow_balance /= 10 ** (18 + 18 - 8);

        require(dai_borrow_balance > 0, "!borrowBalance");

        _pending_flashloan = true;

        // flash loan enough DAI to fully pay back the loan
        _flashloanDAI(dai_borrow_balance, abi.encode(data));
    }

    /*
    Entrypoint for dYdX operations (from IDyDxCallee).

    TODO: this is wrong. this can't work via delegatecall

    TODO: do we care about the account_info?

    it would be nice to allow exiting into other tokens, but that got rather complex
    someone could easily make their own exit contract that does that if they want it
    */
    function callFunction(
        address sender,
        DyDxTypes.AccountInfo calldata /*account_info*/,
        bytes memory encoded_data
    ) external override {
        require(_pending_flashloan, "!pending_flashloan");
        // sender is our original caller. msg.sender is the flash loan provider
        // this isn't really a security check. this is more a safety check
        // TODO: is this check needed? pending_flashloan should be enough
        require(sender == address(this), "!sender");

        _pending_flashloan = false;

        uint256 temp;  // we are going to check a lot of balances

        (uint256 flash_dai_amount, ExitLoanData memory data) = abi.decode(encoded_data, (uint256, ExitLoanData));

        // repay the full borrow amount to unlock all our CY_Y_THREE_CRV
        // TODO: allow partially repaying? repay flash_dai_amount or 2 ** 256 - 1?
        DAI.approve(address(CY_DAI), flash_dai_amount);

        if (data.exit_sender) {
            (uint256 error, ) = CY_DAI.repayBorrowBehalf(sender, flash_dai_amount);
            require(error == 0, "!CY_DAI.repayBorrowBehalf");

            // sender has CY_Y_THREE_CRV free now
            // TODO: don't assume we can move it all. they might want to have other borrows on this same proxy
            temp = CY_Y_THREE_CRV.balanceOf(sender);

            // take the sender's CY_Y_THREE_CRV
            // TODO: make sure our script sets this approval
            require(CY_Y_THREE_CRV.transferFrom(sender, address(this), temp), "!CY_Y_THREE_CRV.transferFrom");
        } else {
            require(CY_DAI.repayBorrow(flash_dai_amount) == 0, "!CY_DAI.repayBorrow");

            // we have CY_Y_THREE_CRV free now
            // TODO: don't assume we can move it all. we might want to have other borrows on this same proxy
            temp = CY_Y_THREE_CRV.balanceOf(address(this));
        }

        // turn CY_Y_THREE_CRV into Y_THREE_CRV
        require(CY_Y_THREE_CRV.redeem(temp) == 0, "!CY_Y_THREE_CRV.redeem");

        // move Y_THREE_CRV
        temp = Y_THREE_CRV.balanceOf(address(this));

        // turn Y_THREE_CRV into THREE_CRV
        Y_THREE_CRV.withdraw(temp);

        // turn THREE_CURVE into DAI
        temp = THREE_CRV_POOL.remove_liquidity_one_coin(temp, 0, data.min_remove_liquidity_dai, true);

        require(temp >= flash_dai_amount, "!flash_dai_amount");

        // set aside the DAI needed to pay back the flash loan
        temp -= flash_dai_amount;

        // tip DAI
        if (data.tip_dai > 0) {
            require(DAI.transfer(data.tip_address, data.tip_dai), "!DAI.transfer tip");

            temp -= data.tip_dai;
        }

        // transfer the rest of the DAI
        require(DAI.transfer(sender, temp), "!DAI.transfer");
    }
}
