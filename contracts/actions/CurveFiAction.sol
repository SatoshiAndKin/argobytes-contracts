// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {ICurveFi} from "contracts/interfaces/curvefi/ICurveFi.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {ArgobytesERC20} from "contracts/library/ArgobytesERC20.sol";
import {Strings2} from "contracts/library/Strings2.sol";
import {
    IERC20,
    SafeERC20
} from "contracts/library/UniversalERC20.sol";

contract CurveFiAction is AbstractERC20Exchange {
    using ArgobytesERC20 for IERC20;
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings2 for address;

    // trade wrapped stablecoins
    function trade(
        address exchange,
        int128 i,
        int128 j,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens
    ) external returnLeftoverToken(src_token) {
        // Use the full balance of tokens
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "CurveFiAction.trade !src_amount");

        IERC20(src_token).approveUnlimitedIfNeeded(exchange, src_amount);

        // do the trade
        ICurveFi(exchange).exchange(i, j, src_amount, dest_min_tokens);

        // check that we received what we expected
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "CurveFiAction.trade !dest_balance"
        );

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
    ) external returnLeftoverToken(src_token) {
        // Use the full balance of tokens
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "CurveFiAction.tradeUnderlying !src_amount");

        IERC20(src_token).approveUnlimitedIfNeeded(exchange, src_amount);

        // do the trade
        ICurveFi(exchange).exchange_underlying(
            i,
            j,
            src_amount,
            dest_min_tokens
        );

        // check that we received what we expected
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "CurveFiAction.tradeUnderlying !dest_balance"
        );

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }
}
