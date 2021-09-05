// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;
pragma abicoder v2;

import {ArgobytesTips} from "contracts/ArgobytesTips.sol";
import {IAaveLendingPool} from "contracts/external/aave/Aave.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";

// TODO: typed errors

/// @title Leverage tokens on Aave V2
contract LeverageAaveAction is ArgobytesTips {
    using SafeERC20 for IERC20;

    struct EnterData {
        IERC20 borrow;
        uint256 borrow_amount;
        IERC20 collateral;
        uint256 collateral_transfer_amount;
        IAaveLendingPool lending_pool;
        address on_behalf_of;
        address swap_contract;  // a standard exchange that trades 100% of a set input amount
        bytes swap_data;
    }

    function enter(EnterData calldata data) external {
        // at this point, we have some collateral tokens from the flash loan

        // transfer the user's initial collateral
        data.collateral.safeTransferFrom(data.on_behalf_of, address(this), data.collateral_transfer_amount);

        uint256 total_collateral = data.collateral.balanceOf(address(this));

        // deposit collateral into Aave
        data.collateral.safeApprove(address(data.lending_pool), total_collateral);
        data.lending_pool.deposit(
            address(data.collateral),
            total_collateral,
            data.on_behalf_of,
            0
        );

        // borrow tokens from Aave
        data.lending_pool.borrow(
            address(data.borrow),
            data.borrow_amount,
            // TODO: allow stable or variable borrows?
            2,
            0,
            data.on_behalf_of
        );
        require(data.borrow_amount > 0, "!borrow_amount");

        // trade borrowed tokens to repay the flash loan
        // because the borrow_amount is fixed, we can use most exchanges direcly without helper actions
        data.borrow.safeApprove(data.swap_contract, data.borrow_amount);
        (bool trade_success, ) = data.swap_contract.call(data.swap_data);
        require(trade_success, "!swap");

        // the flash borrowed amount + flash fee will be pulled by the flash lender. any excess will be sent to the owner
        // on_behalf_of will have a bunch of aToken and debt
    }

    struct ExitData {
        IERC20 borrow;
        IERC20 borrow_debt_token;
        uint256 borrow_transfer_amt;
        IERC20 collateral;
        IERC20 collateral_atoken;
        uint256 collateral_tip_amount; // tip for the developers in aToken
        uint256 collateral_trade_amount; // the amount of collateral exchanged to pay back the flash loan
        IAaveLendingPool lending_pool;
        address on_behalf_of;
        address swap_contract;  // a standard exchange that trades 100% of a set input amount
        bytes swap_data;
    }

    function exit(ExitData calldata data) external {
        if (data.borrow_transfer_amt > 0) {
            data.borrow.safeTransferFrom(data.on_behalf_of, address(this), data.borrow_transfer_amt);
        }

        // at this point, we have some borrow tokens from the flash loan and maybe some extra from borrow_transfer_amt
        uint256 repay_amount = data.borrow.balanceOf(address(this));

        // TODO: this shouldn't be needed, overpayment should be fine. But i'm seeing confusing reverts
        uint256 debt_amount = data.borrow_debt_token.balanceOf(data.on_behalf_of);
        if (debt_amount < repay_amount) {
            repay_amount = debt_amount;
        }

        // repay the loan
        // overpayment is returned (and normal because we want to be sure not to leave any dust behind)
        data.borrow.safeApprove(address(data.lending_pool), repay_amount);
        data.lending_pool.repay(address(data.borrow), repay_amount, 2, data.on_behalf_of);

        // assuming enough was repaid, transfer of collateral_atoken is now allowed

        // Transfer some aToken here to exchange to borrow_token
        data.collateral_atoken.transferFrom(
            data.on_behalf_of, address(this),
            data.collateral_trade_amount + data.collateral_tip_amount
        );

        // optionally tip aToken
        tip_erc20(data.collateral_atoken, data.collateral_tip_amount);

        // burn aToken for the underlying. aTokens are 1:1 with their underlying
        data.collateral_atoken.safeApprove(address(data.lending_pool), data.collateral_trade_amount);
        data.lending_pool.withdraw(address(data.collateral), data.collateral_trade_amount, address(this));

        // trade a known amount of collateral tokens into borrow tokens to repay the flash loan
        // because we know our amount, we call DEXs directly **instead of** an Argobytes Action
        // be sure the minimum exchanged is >= flasah borrowed amount + flashloan fee
        data.collateral.safeApprove(data.swap_contract, data.collateral_trade_amount);
        (bool trade_success, ) = data.swap_contract.call(data.swap_data);
        require(trade_success, "!swap");

        // the flash borrowed amount + flash fee will be pulled by the flash lender. any excess will be sent to the owner
        // on_behalf_of will have a bunch of aToken and less debt
    }
}
