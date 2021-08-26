// SPDX-License-Identifier: MPL-2.0
// TODO: rewrite this to be a target for ArgobytesFlashBorrower
// TODO: consistent revert strings
pragma solidity 0.8.7;
pragma abicoder v2;

import {ArgobytesTips} from "contracts/ArgobytesTips.sol";

import {LeverageCYY3CRVConstants} from "./Constants.sol";

contract ExitCYY3CRVAction is ArgobytesTips, LeverageCYY3CRVConstants {
    /// @notice leveraged cyy3crv -> y3crv -> 3crv -> stablecoins
    /// @dev Delegatecall this from ArgobytesFlashBorrower.flashBorrow
    function exit(
        uint256 dai_flash_fee,
        uint256 max_3crv_burned,
        uint256 tip_3crv,
        address sender
    ) external payable {
        // TODO: does this need auth? not if delegatecall is used. enforce that?

        uint256 flash_dai_amount = DAI.balanceOf(address(this));

        uint256 temp; // we are going to check a lot of balances

        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            address payable tip_address = resolve_tip_address();

            if (tip_address == address(0)) {
                // no tip address. send the tip to sender instead
                (bool success, ) = payable(sender).call{value: msg.value}("");
                require(success, "ExitCYY3CRVAction !tip");
            } else {
                (bool success, ) = tip_address.call{value: msg.value}("");
                require(success, "ExitCYY3CRVAction !tip");
            }
        }

        // TODO: check CY_USDC and CY_USDT (and maybe other things, too)
        uint256 dai_borrow_balance = CY_DAI.borrowBalanceCurrent(address(this));

        require(dai_borrow_balance > 0, "ExitCYY3CRVAction !dai_borrow_balance");
        require(flash_dai_amount >= dai_borrow_balance, "ExitCYY3CRVAction !flash_dai_amount");

        // approve the full borrow amount to unlock all our CY_Y_THREE_CRV
        // TODO: allow partially repaying?
        DAI.approve(address(CY_DAI), dai_borrow_balance);

        require(CY_DAI.repayBorrow(dai_borrow_balance) == 0, "ExitCYY3CRVAction !CY_DAI.repayBorrow");

        // we have CY_Y_THREE_CRV free now
        // TODO: don't assume we can move it all. we might want to have other borrows on this same proxy
        temp = CY_Y_THREE_CRV.balanceOf(address(this));

        // check cyy3crv balance
        require(temp > 0, "ExitCYY3CRVAction debug !cyy3crv");

        // (uint error, uint liquidity, uint shortfall) = CREAM.getHypotheticalAccountLiquidity(address(this), address(CY_Y_THREE_CRV), temp, 0);
        // require(error == 0, "ExitCYY3CRVAction CREAM redeem error");
        // if (shortfall > 0) {
        //     // TODO: why are we reverting here? why can't we withdraw 100%?
        //     revert(string(abi.encodePacked("shortfall: ", Strings.toString(shortfall))));
        // }
        // require(shortfall == 0, "EnterCYY3CRVAction CREAM redeem shortfall");

        // turn CY_Y_THREE_CRV into Y_THREE_CRV (no approval needed)
        require(CY_Y_THREE_CRV.redeem(temp) == 0, "ExitCYY3CRVAction !CY_Y_THREE_CRV.redeem");

        // TODO: transfer Y_THREE_CRV from exit_from?

        // turn Y_THREE_CRV into THREE_CRV (no approval needed)
        temp = Y_THREE_CRV.balanceOf(address(this));

        require(temp > 0, "ExitCYY3CRVAction debug !y3crv");

        // TODO: allow exiting with y3crv?
        Y_THREE_CRV.withdraw(temp);

        // turn enough THREE_CRV into DAI to pay back the flash loan
        temp = THREE_CRV.balanceOf(address(this));

        require(temp >= max_3crv_burned, "ExitCYY3CRVAction debug !3crv");
        require(max_3crv_burned > 0, "ExitCYY3CRVAction debug !max_3crv_burned");

        THREE_CRV.approve(address(THREE_CRV_POOL), max_3crv_burned);

        // add the fee
        // flash loaning max DAI is likely impossible, but even if this rolls over, things revert
        unchecked {
            flash_dai_amount += dai_flash_fee;
        }

        // burn enough 3crv to get back enough DAI to pay back the flash loan
        // we could allow exiting to DAI, USDC, or USDT here, but i think exiting with 3crv makes the most sense
        // TODO: allow withdraw to USDC and USDT, too?
        uint256[3] memory amounts;
        amounts[0] = flash_dai_amount - DAI.balanceOf(address(this));
        amounts[1] = 0;
        amounts[2] = 0;

        // TODO: check that amounts[0] > 0? that shouldn't be possible

        THREE_CRV_POOL.remove_liquidity_imbalance(amounts, max_3crv_burned);

        // hopefully we didn't use all our 3crv paying back the flash loan
        temp = THREE_CRV.balanceOf(address(this));

        if (temp > 0) {
            // TODO: is clearing the approval worthwhile? does it save us gas?
            THREE_CRV.approve(address(THREE_CRV_POOL), 0);
        }

        // tip the developers
        if (tip_3crv > 0) {
            if (tip_3crv > temp) {
                // reverting just because we couldn't tip would be sad. reduce the tip instead
                // TODO: cut the tip in half so they get something back, too?
                tip_3crv = temp;
            }

            address payable tip_address = resolve_tip_address();

            if (tip_address != address(0)) {
                // a revert here should be impossible
                require(THREE_CRV.transfer(tip_address, tip_3crv), "ExitCYY3CRVAction !tip_3crv");

                // no need for checked math since we do a comparison just before this
                unchecked {
                    temp -= tip_3crv;
                }
            }
        }

        // send the rest of the 3crv on
        if (temp > 0) {
            require(THREE_CRV.transfer(sender, temp), "ExitCYY3CRVAction !DAI sweep");
        }
    }
}
