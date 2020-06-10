// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.9;
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

    function sweep(address payable to, IERC20 token) public payable {
        uint256 balance = token.universalBalanceOf(address(this));

        if (to == address(0)) {
            token.universalTransfer(msg.sender, balance);
        } else {
            token.universalTransfer(to, balance);
        }
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
        revert("ExampleAction.newAmount: unimplemented");
    }
}
