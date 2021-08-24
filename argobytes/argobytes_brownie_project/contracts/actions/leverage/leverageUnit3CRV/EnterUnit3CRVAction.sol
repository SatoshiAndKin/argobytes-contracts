// An action for ArgobytesFlashBorrower that borrows DAI and deposits into https://unit.xyz
// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;
pragma abicoder v2;

import {ArgobytesTips} from "contracts/ArgobytesTips.sol";

import {LeverageUnit3CRVConstants} from "./Constants.sol";

contract EnterUnit3CRVAction is ArgobytesTips, LeverageUnit3CRVConstants {
    // this function takes a lot of inputs so we put them into a struct
    // this isn't as gas efficient, but it compiles without "stack too deep" errors
    struct EnterData {
        uint256 dai;
        uint256 dai_flash_fee;
        uint256 usdc;
        uint256 usdt;
        uint256 min_3crv_mint_amount;
        uint256 threecrv;
        uint256 tip_3crv;
        // mint_usdp MUST be enough to cover flash_dai_amount + dai_flash_fee
        uint256 mint_usdp;
        // because of how the flash loans work, we can't use msg.sender
        address sender;
        bool claim_3crv;
    }

    /// @notice stablecoins -> 3crv -> 3crv-gauge-unit <-> borrow usdp
    /// @dev Delegatecall this from ArgobytesFlashBorrower.flashBorrow
    function enter(EnterData calldata data) external payable {
        // we don't need auth here because this is only used via delegatecall that already has auth

        uint256 temp; // we are going to be checking a lot of balances

        // we should already have DAI from the flash loan
        uint256 flash_dai_amount = DAI.balanceOf(address(this));

        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            address payable tip_address = resolve_tip_address();

            (bool success, ) = tip_address.call{value: msg.value}("");
            require(success, "!tip");
        }

        // transfer stablecoins and trade them to 3crv
        {
            // grab the data.sender's DAI
            if (data.dai > 0) {
                // DAI reverts on failure
                DAI.transferFrom(data.sender, address(this), data.dai);

                // approve the upcoming exchange
                DAI.approve(address(THREE_CRV_POOL), flash_dai_amount + data.dai);
            } else {
                // approve the upcoming exchange
                DAI.approve(address(THREE_CRV_POOL), flash_dai_amount);
            }

            // grab the data.sender's USDC
            if (data.usdc > 0) {
                // USDC returns a bool
                require(USDC.transferFrom(data.sender, address(this), data.usdc), "EnterUnit3CRVAction !USDC");

                // approve the upcoming exchange
                USDC.approve(address(THREE_CRV_POOL), data.usdc);
            }

            // grab the data.sender's USDT
            if (data.usdt > 0) {
                // Tether does *not* return a bool! it simply reverts
                USDT.transferFrom(data.sender, address(this), data.usdt);

                // approve the exchange
                USDT.approve(address(THREE_CRV_POOL), data.usdt);
            }

            // trade dai/usdc/usdt into 3crv
            THREE_CRV_POOL.add_liquidity(
                [flash_dai_amount + data.dai, data.usdc, data.usdt],
                data.min_3crv_mint_amount
            );
        }

        // optionally claim 3crv from being a veCRV holder
        uint256 claimed_3crv = 0;
        if (data.claim_3crv) {
            claimed_3crv = THREE_CRV_FEE_DISTRIBUTION.claim(data.sender);
        }

        // grab the data.sender's 3crv
        temp = data.threecrv + claimed_3crv;
        if (temp > 0) {
            require(THREE_CRV.transferFrom(data.sender, address(this), temp), "EnterUnit3CRVAction !THREE_CRV");
        }

        // this contract now has some 3crv

        // optionally tip the developer some 3crv
        if (data.tip_3crv > 0) {
            address payable tip_address = resolve_tip_address();

            require(THREE_CRV.transfer(tip_address, data.tip_3crv), "EnterUnit3CRVAction !tip_3crv");
        }

        // deposit 3crv into 3crv-gauge-unit
        temp = THREE_CRV.balanceOf(address(this));
        THREE_CRV.approve(address(THREE_CRV_GAUGE_UNIT), temp);
        temp = THREE_CRV_GAUGE_UNIT.deposit(temp);
        // temp is now this THREE_CRV_GAUGE_UNIT balance

        // approve the vault (not the CDP manager) to take the 3crv-gauge-unit
        THREE_CRV_GAUGE_UNIT.approve(address(UNIT_VAULT), temp);

        // join deposits 3crv-gauge-unit and mints USDP
        // mint_usdp MUST be enough to cover flash_dai_amount
        UNIT_CDP_MANAGER.join(address(THREE_CRV_GAUGE_UNIT), temp, data.mint_usdp);

        // trade USDP for DAI to pay back the flash loan
        flash_dai_amount += data.dai_flash_fee;
        USDP_POOL.exchange_underlying(0, 1, data.mint_usdp, flash_dai_amount);

        // the flash loan provider will transfer DAI from here to pay bacak the loan
        // the necessary DAI approval is already done

        // TODO: return something?
    }
}
