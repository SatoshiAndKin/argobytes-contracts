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
        address sender;
        IAaveLendingPool lending_pool;
        IERC20 collateral;
        uint256 collateral_amount;
        uint256 collateral_flash_fee;
        IERC20 borrow;
        uint256 borrow_amount;
        address swap_contract;
        bytes swap_data;
    }

    struct ExitData {
        address on_behalf_of;
        uint256 usdt_flash_fee;
    }

    function enter(EnterData calldata data) external {
        // at this point, we have some tokens from the flash loan
        uint256 flash_collateral_amount = data.collateral.balanceOf(address(this));

        // transfer the user's initial collateral
        data.collateral.safeTransferFrom(data.on_behalf_of, address(this), data.collateral_amount);

        // deposit collateral into Aave
        data.lending_pool.deposit(
            address(data.collateral),
            flash_collateral_amount + data.collateral_amount,
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
        (bool trade_success, ) = data.swap_contract.call(data.swap_data);
        require(trade_success, "!swap");

        uint256 balance = data.collateral.balanceOf(address(this));
        flash_collateral_amount += data.collateral_flash_fee;

        require(
            balance >= flash_collateral_amount,
            "!swap balance"
        );

        // check if we have some extra collateral tokens
        if (balance > flash_collateral_amount) {
            data.collateral.safeTransfer(data.on_behalf_of, balance - flash_collateral_amount);
        }
        
        // check if we have some extra borrow tokens
        balance = data.borrow.balanceOf(address(this));
        if (balance > 0) {
            data.borrow.safeTransfer(data.on_behalf_of, balance);
        }

        // flash_collateral_amount will be pulled by the flash lender
    }

    function exit(ExitData calldata data) external {
        revert("wip");
    }
}
