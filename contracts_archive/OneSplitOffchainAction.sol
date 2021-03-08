// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20, SafeERC20} from "contracts/library/UniversalERC20.sol";
import {IOneSplit} from "contracts/external/onesplit/IOneSplit.sol";

contract OneSplitOffchainAction is AbstractERC20Exchange {
    using SafeERC20 for IERC20;

    address constant internal ADDRESS_ZERO = address(0);

    function tradeEtherToToken(
        address exchange,
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256[] calldata distribution,
        uint256 disable_flags
    ) external payable {
        uint256 src_balance = address(this).balance;

        // no approvals are necessary since we are using ETH

        // do the actual swap (and send the ETH along as value)
        IOneSplit(exchange).swap{value: src_balance}(
            ADDRESS_ZERO,
            dest_token,
            src_balance,
            dest_min_tokens,
            distribution,
            disable_flags
        );

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));

        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    function tradeTokenToToken(
        address exchange,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256[] calldata distribution,
        uint256 disable_flags
    ) external {
        uint256 src_balance = IERC20(src_token).balanceOf(address(this));

        // approve the exchange to take our full balance
        IERC20(src_token).approve(exchange, src_balance);

        // do the actual swap
        IOneSplit(exchange).swap(
            src_token,
            dest_token,
            src_balance,
            dest_min_tokens,
            distribution,
            disable_flags
        );

        // forward the tokens that we bought
        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));

        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    function tradeTokenToEther(
        address exchange,
        address payable to,
        address src_token,
        uint256 dest_min_tokens,
        uint256[] calldata distribution,
        uint256 disable_flags
    ) external returnLeftoverToken(src_token) {
        uint256 src_balance = IERC20(src_token).balanceOf(address(this));

        // approve the exchange to take our full balance
        IERC20(src_token).approve(exchange, src_balance);

        // do the actual swap
        IOneSplit(exchange).swap(
            src_token,
            ADDRESS_ZERO,
            src_balance,
            dest_min_tokens,
            distribution,
            disable_flags
        );

        // forward the tokens that we bought
        uint256 dest_balance = address(this).balance;

        Address.sendValue(to, dest_balance);
    }
}
