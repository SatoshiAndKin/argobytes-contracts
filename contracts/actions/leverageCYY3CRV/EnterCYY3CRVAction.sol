// SPDX-License-Identifier: LGPL-3.0-or-later
// TODO: rewrite this to be a target for ArgobytesFlashBorrower
// TODO: consistent revert strings
pragma solidity 0.7.6;
pragma abicoder v2;

import {Constants} from "./Constants.sol";

contract EnterCYY3CRVAction is Constants {

    event ArgobytesLogUint(address indexed proxy, uint8 id, uint256 data);

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
        // because of how the flash loans work, we can't use msg.data.sender
        address sender;
        // TODO: put the tip_address into an immutable and have it be an ENS namehash
        address tip_address;
        bool claim_3crv;
    }

    /// @notice stablecoins -> 3crv -> y3crv -> leveraged cyy3crv
    /// @dev Delegatecall this from ArgobytesFlashBorrower.flashBorrow
    function enter(
        EnterData calldata data
    ) external payable returns (uint256) {
        // TODO: we don't need auth here anymore. this is only used via delegatecall that already has auth. but think about it more

        uint256 temp;  // we are going to be checking a lot of balances

        // we should already have DAI from the flash loan
        uint256 flash_dai_amount = DAI.balanceOf(address(this));

        emit ArgobytesLogUint(address(this), 0, flash_dai_amount);

        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            (bool success, ) = data.tip_address.call{value: msg.value}("");
            require(success, "!tip");
        }

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
                require(USDC.transferFrom(data.sender, address(this), data.usdc), "EnterCYY3CRVAction !USDC");

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
                [
                    flash_dai_amount + data.dai,
                    data.usdc,
                    data.usdt
                ],
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
            require(THREE_CRV.transferFrom(data.sender, address(this), temp), "EnterCYY3CRVAction !THREE_CRV");
        }

        // optionally tip the developer
        if (data.tip_3crv > 0) {
            // TODO: do we want to approve tip_address to pull funds instead and then call some function?
            require(THREE_CRV.transfer(data.tip_address, data.tip_3crv), "EnterCYY3CRVAction !tip_3crv");
        }

        // deposit 3crv for y3crv
        temp = THREE_CRV.balanceOf(address(this));

        emit ArgobytesLogUint(address(this), 1, temp);

        THREE_CRV.approve(address(Y_THREE_CRV), temp);
        Y_THREE_CRV.deposit(temp);

        emit ArgobytesLogUint(address(this), 2, temp);

        // grab the data.sender's y3crv
        if (data.y3crv > 0) {
            require(Y_THREE_CRV.transferFrom(data.sender, address(this), data.y3crv), "EnterCYY3CRVAction !Y_THREE_CRV");
        }

        // setup cream
        address[] memory markets = new address[](1);
        markets[0] = address(CY_Y_THREE_CRV);
        // TODO: do we need cydai?
        // markets[1] = address(CY_DAI);

        CREAM.enterMarkets(markets);

        // deposit y3crv for cyy3crv
        temp = Y_THREE_CRV.balanceOf(address(this));

        emit ArgobytesLogUint(address(this), 3, temp);

        Y_THREE_CRV.approve(address(CY_Y_THREE_CRV), temp);
        require(CY_Y_THREE_CRV.mint(temp) == 0, "EnterCYY3CRVAction !CYY3CRV.mint");

        temp = CY_Y_THREE_CRV.balanceOf(address(this));
        require(temp > 0, "!CY_Y_THREE_CRV mint balance");

        emit ArgobytesLogUint(address(this), 4, temp);

        // TODO: optionally grab the user's cyy3crv. this will revert if they already have borrows. they should probably just exit first

        flash_dai_amount += data.dai_flash_fee;

        emit ArgobytesLogUint(address(this), 5, flash_dai_amount);

        // make sure we can borrow enough DAI from cream
        (uint error, uint liquidity, uint shortfall) = CREAM.getHypotheticalAccountLiquidity(address(this), address(CY_DAI), 0, flash_dai_amount);
        require(error == 0, "EnterCYY3CRVAction CREAM error");
        require(shortfall == 0, "EnterCYY3CRVAction CREAM shortfall");
        require(liquidity >= data.min_cream_liquidity, "EnterCYY3CRVAction !min_cream_liquidity");

        // TODO: do something if liquidity is really large?

        emit ArgobytesLogUint(address(this), 6, liquidity);

        // borrow DAI from cream to pay back the flash loan
        require(CY_DAI.borrow(flash_dai_amount) == 0, "EnterCYY3CRVAction !cydai.borrow");

        return liquidity;
    }
}
