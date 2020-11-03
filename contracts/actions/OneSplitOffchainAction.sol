// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {ArgobytesERC20} from "contracts/library/ArgobytesERC20.sol";
import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20, SafeERC20} from "contracts/library/UniversalERC20.sol";
import {IOneSplit} from "contracts/interfaces/onesplit/IOneSplit.sol";

contract OneSplitOffchainAction is AbstractERC20Exchange {
    using ArgobytesERC20 for IERC20;
    using SafeERC20 for IERC20;

    // call this function offchain. do not include it in your actual transaction or the gas costs are excessive
    function encodeExtraData(
        address src_token,
        address dest_token,
        uint256 src_amount,
        uint256 dest_min_tokens,
        address exchange,
        uint256 parts,
        uint256 disable_flags
    ) external view returns (uint256, bytes memory) {
        require(
            dest_min_tokens > 0,
            "OneSplitOffchainAction.encodeExtraData: dest_min_tokens must be > 0"
        );

        (uint256 expected_return, uint256[] memory distribution) = IOneSplit(
            exchange
        )
            .getExpectedReturn(
            src_token,
            dest_token,
            src_amount,
            parts,
            disable_flags
        );

        require(
            expected_return >= dest_min_tokens,
            "OneSplitOffchainAction.encodeExtraData: LOW_EXPECTED_RETURN"
        );

        // i'd like to put the exchange here, but we need it seperate so that modifiers can access it
        bytes memory encoded = abi.encode(distribution, disable_flags);

        return (expected_return, encoded);
    }

    function tradeEtherToToken(
        address exchange,
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external payable returnLeftoverEther() {
        (uint256[] memory distribution, uint256 disable_flags) = abi.decode(
            extra_data,
            (uint256[], uint256)
        );

        uint256 src_balance = address(this).balance;
        require(
            src_balance > 0,
            "OneSplitOffchainAction.tradeEtherToToken: NO_ETH_BALANCE"
        );

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
        require(
            dest_balance >= dest_min_tokens,
            "OneSplitOffchainAction.tradeEtherToToken: LOW_DEST_BALANCE"
        );

        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    function tradeTokenToToken(
        address exchange,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external returnLeftoverToken(src_token) {
        (uint256[] memory distribution, uint256 disable_flags) = abi.decode(
            extra_data,
            (uint256[], uint256)
        );

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(
            src_balance > 0,
            "OneSplitOffchainAction.tradeTokenToToken: NO_SRC_BALANCE"
        );

        IERC20(src_token).excessiveApprove(exchange, src_balance);

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
        require(
            dest_balance >= dest_min_tokens,
            "OneSplitOffchainAction.tradeTokenToToken: LOW_DEST_BALANCE"
        );

        IERC20(dest_token).safeTransfer(to, dest_balance);
    }

    function tradeTokenToEther(
        address exchange,
        address payable to,
        address src_token,
        uint256 dest_min_tokens,
        bytes calldata extra_data
    ) external returnLeftoverToken(src_token) {
        (uint256[] memory distribution, uint256 disable_flags) = abi.decode(
            extra_data,
            (uint256[], uint256)
        );

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(
            src_balance > 0,
            "OneSplitOffchainAction._tradeTokenToEther: NO_SRC_BALANCE"
        );

        IERC20(src_token).excessiveApprove(exchange, src_balance);

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
        require(
            dest_balance >= dest_min_tokens,
            "OneSplitOffchainAction._tradeTokenToEther: LOW_DEST_BALANCE"
        );

        Address.sendValue(to, dest_balance);
    }
}
