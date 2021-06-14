// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.5;

import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";
import {ICurvePool} from "contracts/external/curvefi/ICurvePool.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

contract CurveFiAction is AbstractERC20Exchange {
    using SafeERC20 for IERC20;

    // trade wrapped stablecoins
    function trade(
        ICurvePool exchange,
        int128 i,
        int128 j,
        address to,
        IERC20 src_token,
        IERC20 dest_token,
        uint256 dest_min_tokens
    ) external {
        // Use the full balance of tokens
        uint256 src_amount = src_token.balanceOf(address(this));

        // require(src_amount > 0, "CurveFiAction.trade: no src_amount");
        // require(exchange.coins(uint256(int256(i))) == src_token, "bad i token");
        // require(exchange.coins(uint256(int256(j))) == dest_token, "bad j token");
        // require(exchange.coins(i) == src_token, "bad i token");
        // require(exchange.coins(j) == dest_token, "bad j token");

        src_token.approve(address(exchange), src_amount);

        // do the trade
        exchange.exchange(i, j, src_amount, dest_min_tokens);

        uint256 dest_balance = dest_token.balanceOf(address(this));

        // require(dest_balance >= dest_min_tokens, "CurveFiAction.trade: no dest_balance");

        if (to != address(this)) {
            // forward the tokens that we bought
            // we NEED this check because some tokens (like compound's cUSDC) revert if to == msg.sender
            dest_token.safeTransfer(to, dest_balance);
        }
    }

    // trade stablecoins
    function tradeUnderlying(
        ICurvePool exchange,
        int128 i,
        int128 j,
        address to,
        IERC20 src_token,
        IERC20 dest_token,
        uint256 dest_min_tokens
    ) external {
        // Use the full balance of tokens
        uint256 src_amount = src_token.balanceOf(address(this));

        // TODO: get src_token and dest_token with coins_underlying
        src_token.approve(address(exchange), src_amount);

        // do the trade
        exchange.exchange_underlying(i, j, src_amount, dest_min_tokens);

        uint256 dest_balance = dest_token.balanceOf(address(this));

        require(dest_balance >= dest_min_tokens, "CurveFiAction.tradeUnderlying: no dest_balance");

        if (to != address(this)) {
            // forward the tokens that we bought
            dest_token.safeTransfer(to, dest_balance);
        }
    }
}
