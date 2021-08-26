// SPDX-License-Identifier: MPL-2.0
// TODO: consistent revert strings
pragma solidity 0.8.7;
pragma abicoder v2;

import {ArgobytesTips} from "contracts/ArgobytesTips.sol";

import {ICERC20, IERC20, LeverageCYY3CRVConstants} from "./Constants.sol";

error CreamBorrowFailed(uint256 error_code, ICERC20 token, uint256 amount);
error CreamMintFailed(uint256 error_code, IERC20 token);
error CreamError(uint256 error_code);
error CreamLiquidity(uint256 liquidity);
error CreamShortfall(uint256 shortfall);
error NoBalance(IERC20 token);
error TransferFailed(IERC20 token);

/// @title Leverage cyy3crv
contract EnterCYY3CRVAction is ArgobytesTips, LeverageCYY3CRVConstants {
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
        uint256 y3crv;
        uint256 min_cream_liquidity;
        // because of how the flash loans work, we can't use msg.sender
        address sender;
        bool claim_3crv;
    }

    /// @notice stablecoins -> 3crv -> y3crv -> leveraged cyy3crv
    /// @dev Delegatecall this from ArgobytesFlashBorrower.flashBorrow
    function enter(EnterData calldata data) external payable {
        // TODO: we don't need auth here anymore. this is only used via delegatecall that already has auth. but think about it more

        uint256 temp; // we are going to be checking a lot of balances

        // we should already have DAI from the flash loan
        uint256 flash_dai_amount = DAI.balanceOf(address(this));

        // send any ETH as a tip to the developer
        tip_eth(msg.value);

        // transfer stablecoins and trade them to 3crv
        {
            // grab the data.sender's DAI
            if (data.dai > 0) {
                // DAI reverts on failure
                DAI.transferFrom(data.sender, address(this), data.dai);

                // approve the exchange
                DAI.approve(address(THREE_CRV_POOL), flash_dai_amount + data.dai);
            } else {
                // approve the exchange
                DAI.approve(address(THREE_CRV_POOL), flash_dai_amount);
            }

            // grab the data.sender's USDC
            if (data.usdc > 0) {
                if (!USDC.transferFrom(data.sender, address(this), data.usdc)) {
                    revert TransferFailed(USDC);
                }

                // approve the exchange
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

        // claim any 3crv from being a veCRV holder
        uint256 claimed_3crv = 0;
        if (data.claim_3crv) {
            claimed_3crv = THREE_CRV_FEE_DISTRIBUTION.claim(data.sender);
            // we add this to principal_amount when handling data.threecrv
        }

        // grab the data.sender's 3crv
        temp = data.threecrv + claimed_3crv;
        if (temp > 0) {
            if (!THREE_CRV.transferFrom(data.sender, address(this), temp)) {
                revert TransferFailed(THREE_CRV);
            }
        }

        // optionally tip the developer
        tip_erc20(THREE_CRV, data.tip_3crv);

        // deposit 3crv for y3crv
        temp = THREE_CRV.balanceOf(address(this));

        THREE_CRV.approve(address(Y_THREE_CRV), temp);
        Y_THREE_CRV.deposit(temp);

        // grab the data.sender's y3crv
        if (data.y3crv > 0) {
            if (!Y_THREE_CRV.transferFrom(data.sender, address(this), data.y3crv)) {
                revert TransferFailed(Y_THREE_CRV);
            }
        }

        // setup cream
        address[] memory markets = new address[](1);
        markets[0] = address(CY_Y_THREE_CRV);

        CREAM.enterMarkets(markets);

        // deposit y3crv for cyy3crv
        temp = Y_THREE_CRV.balanceOf(address(this));

        Y_THREE_CRV.approve(address(CY_Y_THREE_CRV), temp);

        temp = CY_Y_THREE_CRV.mint(temp);
        if (temp != 0) {
            revert CreamMintFailed(temp, IERC20(CY_Y_THREE_CRV));
        }

        temp = CY_Y_THREE_CRV.balanceOf(address(this));
        if (temp == 0) {
            revert NoBalance(CY_Y_THREE_CRV);
        }

        flash_dai_amount += data.dai_flash_fee;

        // make sure we can borrow DAI from cream and still have a healthy collateralization
        (uint256 error_code, uint256 liquidity, uint256 shortfall) = CREAM.getHypotheticalAccountLiquidity(
            address(this),
            address(CY_DAI),
            0,
            flash_dai_amount
        );

        if (error_code != 0) {
            revert CreamError(error_code);
        }
        if (shortfall != 0) {
            revert CreamShortfall(shortfall);
        }
        if (liquidity < data.min_cream_liquidity) {
            revert CreamLiquidity(liquidity);
        }

        // TODO: do something if liquidity is really large?

        // borrow DAI from cream to pay back the flash loan
        temp = CY_DAI.borrow(flash_dai_amount);
        if (temp != 0) {
            revert CreamBorrowFailed(temp, CY_DAI, flash_dai_amount);
        }
    }
}
