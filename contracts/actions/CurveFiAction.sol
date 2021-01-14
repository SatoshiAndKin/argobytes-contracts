// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@OpenZeppelin/token/ERC20/SafeERC20.sol";

import {ICurveFi} from "contracts/interfaces/curvefi/ICurveFi.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

contract CurveFiAction is AbstractERC20Exchange {
    using SafeERC20 for IERC20;

    // trade wrapped stablecoins
    function trade(
        address exchange,
        int128 i,
        int128 j,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens
    ) external {
        // Use the full balance of tokens
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));

        // require(src_amount > 0, "CurveFiAction.trade: no src_amount");

        IERC20(src_token).approve(exchange, src_amount);

        // do the trade
        ICurveFi(exchange).exchange(i, j, src_amount, dest_min_tokens);

        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    // trade stablecoins
    function tradeUnderlying(
        address exchange,
        int128 i,
        int128 j,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens
    ) external {
        // Use the full balance of tokens
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));

        // require(src_amount > 0, "CurveFiAction.tradeUnderlying: no src_amount");

        IERC20(src_token).approve(exchange, src_amount);

        // do the trade
        ICurveFi(exchange).exchange_underlying(
            i,
            j,
            src_amount,
            dest_min_tokens
        );

        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }
}
