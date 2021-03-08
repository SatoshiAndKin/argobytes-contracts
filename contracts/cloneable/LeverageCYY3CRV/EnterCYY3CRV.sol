// SPDX-License-Identifier: LGPL-3.0-or-later
// don't call this contract directly! use a proxy like DSProxy or ArgobytesProxy!
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
pragma solidity 0.7.6;
pragma abicoder v2;

import {Constants} from "./Constants.sol";
import {DyDxCallee, DyDxTypes} from "./DyDxCallee.sol";

import {ArgobytesClone} from "contracts/abstract/ArgobytesClone.sol";


contract EnterCYY3CRV is ArgobytesClone, Constants, DyDxCallee {

    bool _pending_flashloan = false;

    struct EnterData {
        uint256 dai;
        uint256 usdc;
        uint256 usdt;
        uint256 threecrv;
        uint256 tip_3crv;
        uint256 y3crv;
        address tip_address;
        bool claim_3crv;
    }

    struct EnterLoanData {
        uint256 min_3crv_mint_amount;
    }

    /* Users should delegatecall this function through a proxy. Be sure to set approvals first! */
    function enter(
        EnterData calldata data,
        EnterLoanData calldata loan_data
    ) external payable onlyOwner {
        // TODO: add the "onlyOwner" modifier to this once it works

        uint256 temp;  // we are going to be checking a lot of balances
        uint256 flash_dai_amount = 0;

        // send any ETH as a tip to the developer
        if (msg.value > 0) {
            (bool success, ) = data.tip_address.call{value: msg.value}("");
            require(success, "!tip");
        }

        // claim any 3crv from being a veCRV holder
        uint256 claimed_3crv = 0;
        if (data.claim_3crv) {
            claimed_3crv = THREE_CRV_FEE_DISTRIBUTION.claim(msg.sender);
        }

        // transfer initial tokens
        if (data.dai > 0) {
            require(DAI.transferFrom(msg.sender, address(this), data.dai), "DAI.transferFrom start");
            flash_dai_amount += data.dai;
        }
        if (data.usdc > 0) {
            require(USDC.transferFrom(msg.sender, address(this), data.usdc), "USDC.transferFrom start");
            flash_dai_amount += data.usdc;
        }
        if (data.usdt > 0) {
            // Tether does *not* return a bool!
            USDT.transferFrom(msg.sender, address(this), data.usdt);
            flash_dai_amount += data.usdt;
        }

        temp = data.threecrv + claimed_3crv;
        if (temp > 0) {
            require(THREE_CRV.transferFrom(msg.sender, address(this), temp), "THREE_CRV.transferFrom start");

            if (data.tip_3crv > 0) {
                // TODO: do we want to approve tip_address to pull funds instead and then call some function?
                require(THREE_CRV.transfer(data.tip_address, data.tip_3crv), "!THREE_CRV.transfer tip");

                temp -= data.tip_3crv;
            }

            temp *= THREE_CRV_POOL.get_virtual_price();

            flash_dai_amount += temp;
        }

        if (data.y3crv > 0) {
            temp = data.y3crv;

            require(Y_THREE_CRV.transferFrom(msg.sender, address(this), temp), "Y_THREE_CRV.transferFrom start");

            temp *= THREE_CRV_POOL.get_virtual_price() / 1e18;
            temp *= Y_THREE_CRV.getPricePerFullShare() / 1e18;

            flash_dai_amount += temp;
        }

        // TODO: allow customizing this? we might want less if the borrow rate in cream is too high
        // 8.4x seems to be the max (see the math in the README). we have 1x and we flash loan 7.4x
        flash_dai_amount *= 74;
        flash_dai_amount /= 10;

        _pending_flashloan = true;

        _flashloanDAI(flash_dai_amount, abi.encode(loan_data));
    }

    /*
    Entrypoint for dYdX operations (from IDyDxCallee).

    TODO: do we care about the account_info?
    */
    function callFunction(
        address sender,
        DyDxTypes.AccountInfo calldata /*account_info*/,
        bytes memory encoded_data
    ) external override {
        require(_pending_flashloan, "!pending_flashloan");
        require(sender == address(this), "!sender");  // TODO: is this check needed? pending_flashloan should be enough

        _pending_flashloan = false;

        (uint256 flash_dai_amount, EnterLoanData memory data) = abi.decode(encoded_data, (uint256, EnterLoanData));

        // approvals
        uint256 dai_balance = DAI.balanceOf(address(this));
        if (dai_balance > 0) {
            DAI.approve(address(THREE_CRV_POOL), dai_balance);
        }

        uint256 usdc_balance = USDC.balanceOf(address(this));
        if (usdc_balance > 0) {
            USDC.approve(address(THREE_CRV_POOL), usdc_balance);
        }

        uint256 usdt_balance = USDT.balanceOf(address(this));
        if (usdt_balance > 0) {
            USDT.approve(address(THREE_CRV_POOL), usdt_balance);
        }

        // trade dai/usdc/usdt into 3crv
        THREE_CRV_POOL.add_liquidity(
            [
                dai_balance,
                usdc_balance,
                usdt_balance
            ],
            data.min_3crv_mint_amount
        );

        uint256 temp;  // we are going to be checking a lot of balances

        // deposit 3crv for y3crv
        temp = THREE_CRV.balanceOf(address(this));

        THREE_CRV.approve(address(Y_THREE_CRV), temp);
        Y_THREE_CRV.deposit(temp);

        // setup cream
        if (!CREAM.checkMembership(address(this), address(CY_Y_THREE_CRV))) {
            // if we aren't in the cyy3crv market, then we aren't in cydai either
            address[] memory markets = new address[](2);
            markets[0] = address(CY_Y_THREE_CRV);
            markets[1] = address(CY_DAI);

            CREAM.enterMarkets(markets);
            // TODO: check the return?
        }

        // deposit y3crv for cyy3crv
        temp = Y_THREE_CRV.balanceOf(address(this));

        Y_THREE_CRV.approve(address(CY_Y_THREE_CRV), temp);
        require(CY_Y_THREE_CRV.mint(temp) == 0, "!cyy3crv.mint");

        // make sure we can borrow enough DAI from cream
        // TODO: should we use CREAM.getAccountLiquidity and then set the borrow based on that? that will give us some excess DAI
        (uint error, uint liquidity, uint shortfall) = CREAM.getHypotheticalAccountLiquidity(address(this), address(CY_DAI), 0, flash_dai_amount);
        require(error == 0, "CREAM error");
        require(shortfall == 0, "CREAM underwater");
        // TODO: how much headroom should we require?
        require(liquidity > 100 * 1e18, "CREAM empty");

        // TODO: if liquidity is large, we did some math wrong. maybe we got lucky on add_liquidity bonus. think about this more
        require(liquidity < 1000 * 1e18, "CREAM overfilled");

        // borrow DAI to pay back the flash loan
        // we already approved this
        require(CY_DAI.borrow(flash_dai_amount) == 0, "!cydai.borrow");
    }
}
