// SPDX-License-Identifier: MPL-2.0
// TODO: consistent revert strings
pragma solidity 0.8.7;
pragma abicoder v2;

import {ArgobytesTips} from "contracts/ArgobytesTips.sol";
import {IAaveLendingPool} from "contracts/external/aave/Aave.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";

// TODO: typed errors

/// @title Leverage cyy3crv
contract LeverageAave is ArgobytesTips {
    using SafeERC20 for IERC20;

    struct EnterData {
        address on_behalf_of;
        IAaveLendingPool lending_pool;
        IERC20 collateral;
        uint256 collateral_amount;
        uint256 collateral_flash_fee;
        uint256 collateral_tip;
        IERC20 borrow;
        uint256 borrow_amount;
        address swap_contract;
        bytes swap_data;
    }

    struct ExitData {
        address on_behalf_of;
        IAaveLendingPool lending_pool;
        IERC20 borrow;
        IERC20 collateral;
        IERC20 collateral_atoken;  // TODO: more  specific type?
        uint256 collateral_atoken_amount;
        uint256 collateral_withdraw_amount;
        uint256 borrow_flash_fee;
        uint256 collateral_swap_amount;
        address swap_contract;
        bytes swap_data;
    }

    function enter(EnterData calldata data) external {
        // at this point, we have some tokens from the flash loan
        uint256 flash_collateral_amount = data.collateral.balanceOf(address(this));

        // transfer the user's initial collateral
        data.collateral.safeTransferFrom(data.on_behalf_of, address(this), data.collateral_amount);

        uint256 additional_collateral = flash_collateral_amount + data.collateral_amount;

        // deposit collateral into Aave
        data.collateral.approve(address(data.lending_pool), additional_collateral);
        data.lending_pool.deposit(
            address(data.collateral),
            additional_collateral,
            data.on_behalf_of,
            0
        );

        // borrow tokens from Aave
        data.lending_pool.borrow(
            address(data.borrow),
            data.borrow_amount,
            2,
            0,
            data.on_behalf_of
        );

        // trade borrowed tokens to repay the flash loan
        data.borrow.transfer(data.swap_contract, data.borrow_amount);
        (bool trade_success, ) = data.swap_contract.call(data.swap_data);
        require(trade_success, "!swap");

        // we need to pay back the flash loan
        flash_collateral_amount += data.collateral_flash_fee;

        // make sure we traded enough to pay back the flash loan
        uint256 balance = data.collateral.balanceOf(address(this));
        require(
            balance >= flash_collateral_amount,
            "!swap balance"
        );

        // check if we have any extra collateral tokens
        if (balance > flash_collateral_amount) {
            data.collateral.safeTransfer(data.on_behalf_of, balance - flash_collateral_amount);
        }
        
        // check if we have any extra borrow tokens
        balance = data.borrow.balanceOf(address(this));
        if (balance > 0) {
            data.borrow.safeTransfer(data.on_behalf_of, balance);
        }

        // flash_collateral_amount will be pulled by the flash lender
    }

    function exit(ExitData calldata data) external {
        // at this point, we have some tokens from the flash loan
        uint256 flash_borrow_amount = data.borrow.balanceOf(address(this));

        // repay the loan with the flash loaned tokens
        data.borrow.approve(address(data.lending_pool), flash_borrow_amount);
        data.lending_pool.repay(address(data.borrow), flash_borrow_amount, 2, data.on_behalf_of);

        // Transfer aToken here
        // TODO: calculate collateral_atoken_amount based on what we repaid?
        data.collateral_atoken.transferFrom(data.on_behalf_of, address(this), data.collateral_atoken_amount);

        // Burn aToken for the underlying
        data.collateral_atoken.approve(address(data.lending_pool), data.collateral_withdraw_amount);
        data.lending_pool.withdraw(address(data.collateral), data.collateral_withdraw_amount, address(this));

        // we need to pay back the flash loan
        flash_borrow_amount += data.borrow_flash_fee;

        // trade collateral tokens to repay the flash loan
        data.collateral.transfer(data.swap_contract, data.collateral_swap_amount);
        (bool trade_success, ) = data.swap_contract.call(data.swap_data);
        require(trade_success, "!swap");

        // make sure we traded enough to pay back the flash loan
        uint256 balance = data.borrow.balanceOf(address(this));
        require(
            balance >= flash_borrow_amount,
            "!swap balance"
        );
        // check if we have any extra borrow tokens
        if (balance > flash_borrow_amount) {
            data.borrow.safeTransfer(data.on_behalf_of, balance - flash_borrow_amount);
        }

        // check if we have any extra collateral tokens
        balance = data.collateral.balanceOf(address(this));
        if (balance > 0) {
            data.collateral.safeTransfer(data.on_behalf_of, balance);
        }

        // check if we have any leftover a tokens
        balance = data.collateral_atoken.balanceOf(address(this));
        if (balance > 0) {
            data.collateral_atoken.safeTransfer(data.on_behalf_of, balance);
        }

        // flash_borrow_amount will be pulled by the flash lender
    }
}
