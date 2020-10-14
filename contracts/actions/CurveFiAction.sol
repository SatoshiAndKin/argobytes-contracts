// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {ICurveFi} from "contracts/interfaces/curvefi/ICurveFi.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {Strings2} from "contracts/library/Strings2.sol";
import {
    IERC20,
    SafeERC20,
    UniversalERC20
} from "contracts/library/UniversalERC20.sol";

contract CurveFiAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;
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
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external returnLeftoverToken(src_token, ADDRESS_ZERO) {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(src_amount > 0, "CurveFiAction.trade: NO_SOURCE_AMOUNT");

        // do the trade (approve was already called)
        ICurveFi(exchange).exchange(i, j, src_amount, dest_min_tokens);

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));
        require(
            dest_balance >= dest_min_tokens,
            "CurveFiAction.trade: LOW_DEST_BALANCE"
        );

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    // trade stablecoins
    // we use ADDRESS_ZERO for returnLeftoverToken because we do NOT want to clear our infinite approvals
    function tradeUnderlying(
        address exchange,
        int128 i,
        int128 j,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external returnLeftoverToken(src_token, ADDRESS_ZERO) {
        // TODO: get src_token and dest_token from storage?

        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(
            src_amount > 0,
            "CurveFiAction.tradeUnderlying: NO_SOURCE_AMOUNT"
        );

        // do the trade (approve was already called)
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
            "CurveFiAction.tradeUnderlying: LOW_DEST_BALANCE"
        );

        // forward the tokens that we bought
        IERC20(dest_token).safeTransfer(to, dest_balance);
    }
}
