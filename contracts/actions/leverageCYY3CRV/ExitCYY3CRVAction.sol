// SPDX-License-Identifier: LGPL-3.0-or-later
// TODO: rewrite this to be a target for ArgobytesFlashBorrower
// TODO: consistent revert strings
pragma solidity 0.7.6;
pragma abicoder v2;

import {Constants} from "./Constants.sol";


contract ExitCYY3CRVAction is Constants {

    /// @dev call this offchain, add some slippage, and use this for the flash loan amount
    function calculateExit(address exit_account) public returns (uint256 dai_borrow_balance) {
        // https://compound.finance/docs#protocol-math
        dai_borrow_balance = CY_DAI.exchangeRateCurrent();

        dai_borrow_balance *= CY_DAI.borrowBalanceCurrent(exit_account);

        dai_borrow_balance /= 10 ** (18 + 18 - 8);
    }

    /// @notice leveraged cyy3crv -> y3crv -> 3crv -> stablecoins
    /// @dev Delegatecall this from ArgobytesFlashBorrower.flashBorrow
    function exit(
        uint256 min_remove_liquidity_dai,
        uint256 tip_dai,
        uint256 dai_flash_fee,
        address tip_address,
        address exit_from,
        address exit_to
    ) external payable {
        // TODO: does this need auth? not if delegatecall is used. enforce that?

        uint256 flash_dai_amount = DAI.balanceOf(address(this));

        uint256 temp;  // we are going to check a lot of balances

        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            (bool success, ) = tip_address.call{value: msg.value}("");
            require(success, "ExitCYY3CRVAction !tip");
        }

        uint256 dai_borrow_balance = calculateExit(exit_from);

        require(flash_dai_amount >= dai_borrow_balance, "ExitCYY3CRVAction !flash_dai_amount");

        // repay the full borrow amount to unlock all our CY_Y_THREE_CRV
        // TODO: allow partially repaying?
        DAI.approve(address(CY_DAI), dai_borrow_balance);

        if (exit_from == address(0)) {
            require(CY_DAI.repayBorrow(dai_borrow_balance) == 0, "ExitCYY3CRVAction !CY_DAI.repayBorrow");

            // we have CY_Y_THREE_CRV free now
            // TODO: don't assume we can move it all. we might want to have other borrows on this same proxy
            temp = CY_Y_THREE_CRV.balanceOf(address(this));
        } else {
            (uint256 error, ) = CY_DAI.repayBorrowBehalf(exit_from, dai_borrow_balance);
            require(error == 0, "ExitCYY3CRVAction !CY_DAI.repayBorrowBehalf");

            // sender has CY_Y_THREE_CRV free now
            // TODO: don't assume we can move it all. they might want to have other borrows on this same proxy
            temp = CY_Y_THREE_CRV.balanceOf(exit_from);

            // take the sender's CY_Y_THREE_CRV
            // TODO: make sure our script sets this approval
            require(CY_Y_THREE_CRV.transferFrom(exit_from, address(this), temp), "ExitCYY3CRVAction !CY_Y_THREE_CRV.transferFrom");
        }

        // turn CY_Y_THREE_CRV into Y_THREE_CRV (no approval needed)
        require(CY_Y_THREE_CRV.redeem(temp) == 0, "ExitCYY3CRVAction !CY_Y_THREE_CRV.redeem");

        // TODO: transfer Y_THREE_CRV from exit_from?

        // turn Y_THREE_CRV into THREE_CRV (no approval needed)
        temp = Y_THREE_CRV.balanceOf(address(this));
        Y_THREE_CRV.withdraw(temp);

        // TODO: transfer THREE_CRV from exit_from?

        // turn all THREE_CRV into DAI
        // TODO: option to just trade enough to pay back the flashloan
        temp = THREE_CRV.balanceOf(address(this));

        THREE_CRV.approve(address(THREE_CRV_POOL), temp);

        THREE_CRV_POOL.remove_liquidity_one_coin(temp, 0, min_remove_liquidity_dai, true);
        // remove_liquidity_one_coin returns the DAI balance, but we might have some excess from a bigger flash loan
        temp = DAI.balanceOf(address(this));

        // add the fee
        flash_dai_amount += dai_flash_fee;

        // make sure we have enough DAI
        require(temp + tip_dai >= flash_dai_amount, "ExitCYY3CRVAction !flash_dai_amount");

        // set aside the DAI needed to pay back the flash loan
        temp -= flash_dai_amount;

        // tip DAI
        if (tip_dai > 0) {
            require(DAI.transfer(tip_address, tip_dai), "ExitCYY3CRVAction !DAI.transfer tip");

            temp -= tip_dai;
        }

        // send the rest of the DAI on
        require(DAI.transfer(exit_to, temp), "ExitCYY3CRVAction !DAI sweep");
    }
}
