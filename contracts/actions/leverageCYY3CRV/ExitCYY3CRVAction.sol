// SPDX-License-Identifier: LGPL-3.0-or-later
// TODO: rewrite this to be a target for ArgobytesFlashBorrower
// TODO: consistent revert strings
pragma solidity 0.8.3;
pragma abicoder v2;

import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {ArgobytesTips} from "contracts/ArgobytesTips.sol";

import {Constants} from "./Constants.sol";

contract ExitCYY3CRVAction is ArgobytesTips, Constants {

    /// @notice leveraged cyy3crv -> y3crv -> 3crv -> stablecoins
    /// @dev Delegatecall this from ArgobytesFlashBorrower.flashBorrow
    function exit(
        uint256 min_remove_liquidity_dai,
        uint256 tip_dai,
        uint256 dai_flash_fee,
        address exit_from,
        address exit_to
    ) external payable {
        // TODO: does this need auth? not if delegatecall is used. enforce that?

        uint256 flash_dai_amount = DAI.balanceOf(address(this));

        uint256 temp;  // we are going to check a lot of balances

        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            address payable tip_address = resolve_tip_address();

            (bool success, ) = tip_address.call{value: msg.value}("");
            require(success, "ExitCYY3CRVAction !tip");
        }

        if (exit_from == address(0)) {
            uint256 dai_borrow_balance = CY_DAI.borrowBalanceCurrent(address(this));

            require(dai_borrow_balance > 0, "ExitCYY3CRVAction !dai_borrow_balance");
            require(flash_dai_amount >= dai_borrow_balance, "ExitCYY3CRVAction !flash_dai_amount");

            // approve the full borrow amount to unlock all our CY_Y_THREE_CRV
            // TODO: allow partially repaying?
            DAI.approve(address(CY_DAI), dai_borrow_balance);

            // debug check
            // require(CY_DAI.balanceOf(address(this)) > 0, "ExitCYY3CRVAction debug !CY_DAI.balance 1");
            uint256 borrow_before_repay = CY_DAI.borrowBalanceCurrent(address(this));
            require(borrow_before_repay > 0, "ExitCYY3CRVAction debug !CY_DAI.borrowBalanceCurrent");

            uint256 dai_before_repay = DAI.balanceOf(address(this));
            require(dai_before_repay >= dai_borrow_balance, "ExitCYY3CRVAction debug !DAI.balance before repay");

            require(CY_DAI.repayBorrow(dai_borrow_balance) == 0, "ExitCYY3CRVAction !CY_DAI.repayBorrow");

            require(DAI.balanceOf(address(this)) < dai_before_repay, "ExitCYY3CRVAction !DAI.balance after repay");

            // debug check
            uint256 borrow_after_repay = CY_DAI.borrowBalanceCurrent(address(this));

            if (borrow_after_repay > 0) {
                // TODO: why are we reverting here? why can't we withdraw 100%?
                revert(string(abi.encodePacked("CY_DAI.borrowBalance after repayBorrow: ", Strings.toString(borrow_before_repay), " -> ", Strings.toString(borrow_after_repay))));
            }

            require(borrow_after_repay == 0, "ExitCYY3CRVAction debug !CY_DAI.balance 3");

            // we have CY_Y_THREE_CRV free now
            // TODO: don't assume we can move it all. we might want to have other borrows on this same proxy
            temp = CY_Y_THREE_CRV.balanceOf(address(this));
        } else {
            // uint256 dai_borrow_balance = CY_DAI.borrowBalanceCurrent(exit_from);

            // require(dai_borrow_balance > 0, "ExitCYY3CRVAction !dai_borrow_balance");
            // require(flash_dai_amount >= dai_borrow_balance, "ExitCYY3CRVAction !flash_dai_amount");

            // // repay the full borrow amount to unlock all our CY_Y_THREE_CRV
            // // TODO: allow partially repaying?
            // DAI.approve(address(CY_DAI), dai_borrow_balance);

            // (uint256 error, ) = CY_DAI.repayBorrowBehalf(exit_from, dai_borrow_balance);
            // require(error == 0, "ExitCYY3CRVAction !CY_DAI.repayBorrowBehalf");

            // // sender has CY_Y_THREE_CRV free now
            // // TODO: don't assume we can move it all. they might want to have other borrows on this same proxy
            // temp = CY_Y_THREE_CRV.balanceOf(exit_from);

            // // take the sender's CY_Y_THREE_CRV
            // // TODO: make sure our script sets this approval
            // require(CY_Y_THREE_CRV.transferFrom(exit_from, address(this), temp), "ExitCYY3CRVAction !CY_Y_THREE_CRV.transferFrom");

            // TODO: do we need to enter a market?
            revert("wip");
        }

        // check cyy3crv balance
        require(temp > 0, "ExitCYY3CRVAction debug !cyy3crv");

        temp = 100;

        (uint error, uint liquidity, uint shortfall) = CREAM.getHypotheticalAccountLiquidity(address(this), address(CY_Y_THREE_CRV), temp, 0);
        require(error == 0, "ExitCYY3CRVAction CREAM redeem error");

        if (shortfall > 0) {
            // TODO: why are we reverting here? why can't we withdraw 100%?
            revert(string(abi.encodePacked("shortfall: ", Strings.toString(shortfall))));
        }

        require(shortfall == 0, "EnterCYY3CRVAction CREAM redeem shortfall");

        // turn CY_Y_THREE_CRV into Y_THREE_CRV (no approval needed)
        require(CY_Y_THREE_CRV.redeem(temp) == 0, "ExitCYY3CRVAction !CY_Y_THREE_CRV.redeem");

        // TODO: transfer Y_THREE_CRV from exit_from?

        // turn Y_THREE_CRV into THREE_CRV (no approval needed)
        temp = Y_THREE_CRV.balanceOf(address(this));

        require(temp > 0, "ExitCYY3CRVAction debug !y3crv");

        Y_THREE_CRV.withdraw(temp);

        // TODO: transfer THREE_CRV from exit_from?

        // turn all THREE_CRV into DAI
        // TODO: option to just trade enough to pay back the flashloan
        temp = THREE_CRV.balanceOf(address(this));

        require(temp > 0, "ExitCYY3CRVAction debug !3crv");
        require(min_remove_liquidity_dai > 0, "ExitCYY3CRVAction debug !min_remove_liquidity_dai");

        THREE_CRV.approve(address(THREE_CRV_POOL), temp);

        // add the fee
        flash_dai_amount += dai_flash_fee;

        // make sure our trade will get enough DAI back
        require(min_remove_liquidity_dai >= flash_dai_amount, "ExitCYY3CRVAction !flash_dai_amount");

        THREE_CRV_POOL.remove_liquidity_one_coin(temp, int128(0), min_remove_liquidity_dai);
        // remove_liquidity_one_coin returns the DAI balance, but we might have some excess from a bigger flash loan
        temp = DAI.balanceOf(address(this));

        // set aside the DAI needed to pay back the flash loan
        temp -= flash_dai_amount;

        // tip the developers
        if (tip_dai > 0) {
            if (tip_dai > temp) {
                // reverting just because we couldn't tip would be sad. reduce the tip instead
                tip_dai = temp;
            }

            address payable tip_address = resolve_tip_address();

            // a revert here should be impossible
            require(DAI.transfer(tip_address, tip_dai), "ExitCYY3CRVAction !DAI.transfer tip");

            temp -= tip_dai;
        }

        // send the rest of the DAI on
        if (temp > 0) {
            require(DAI.transfer(exit_to, temp), "ExitCYY3CRVAction !DAI sweep");
        }
    }
}
