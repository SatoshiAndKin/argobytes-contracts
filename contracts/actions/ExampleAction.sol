// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";


contract ExampleAction is AbstractERC20Exchange {
    using UniversalERC20 for IERC20;

    function fail() public payable {
        revert("ExampleAction: fail function always reverts");
    }

    function noop() public payable returns (bool) {
        return true;
    }

    function sweep(IERC20 token) public payable {
        uint256 balance = token.universalBalanceOf(address(this));

        token.universalTransfer(msg.sender, balance);
    }

    function _tradeEtherToToken(
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens,
        bytes memory
    ) internal override {
        to;
        dest_token;
        dest_min_tokens;
        dest_max_tokens;
    }

    function _tradeTokenToToken(
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens,
        bytes memory
    ) internal override {
        to;
        src_token;
        dest_token;
        dest_min_tokens;
        dest_max_tokens;
    }

    function _tradeTokenToEther(
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens,
        bytes memory
    ) internal override {
        to;
        src_token;
        dest_min_tokens;
        dest_max_tokens;
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = "";

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_address,
        uint256 taker_wei,
        address taker_address,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        revert("wip");
    }
}
