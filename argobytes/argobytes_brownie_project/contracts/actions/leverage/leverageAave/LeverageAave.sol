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
        address onBehalfOf;
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
        address onBehalfOf;
        uint256 usdt_flash_fee;
    }

    function enter(EnterData calldata data) external payable {
        // this is only used via delegatecall that already has auth. but think about auth more

        // we should already have DAI from the flash loan
        uint256 flash_collateral_amount = collateral.balanceOf(address(this));

        collateral.safeTransferFrom(data.onBehalfOf, data.collateral_amount);

        data.lending_pool.deposit(
            collateral,
            flash_collateral_amount + data.collateral_amount,
            onBehalfOf,
            0
        );

        data.lending_pool.borrow(
            borrow,
            borrow_amount,
            2,
            0,
            onBehalfOf
        );

        (bool trade_success, ) = swap_contract.call(data.swap_data);
        require(trade_success, "!swap");
        require(
            collateral.balanceOf(address(this)) > flash_collateral_amount + data.collateral_flash_fee,
            "!swap balance"
        );
    }

    function exit(ExitData calldata data) external {
        revert("wip");
    }
}
