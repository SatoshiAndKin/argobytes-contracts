// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {UniversalERC20, IERC20} from "contracts/UniversalERC20.sol";
import {AbstractERC20Modifiers} from "./AbstractERC20Exchange.sol";

contract ZrxV3Action is AbstractERC20Modifiers {
    using UniversalERC20 for IERC20;

    function trade(
        address zrx_forwarder,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes memory zrx_data
    ) public payable returnLeftoverUniversal(src_token, zrx_forwarder) {
        uint256 src_balance = IERC20(src_token).universalBalanceOf(address(this));

        IERC20(src_token).universalApprove(zrx_forwarder, src_balance);

        (bool success, ) = address(zrx_forwarder).call{value: msg.value}(zrx_data);

        // TODO: better error message
        require(success, "0x call failed");

        uint256 dest_balance = IERC20(dest_token).balanceOf(address(this));

        require(dest_balance >= dest_min_tokens, "ZrxV3Action.trade: not enough destination token received");

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        require(IERC20(dest_token).transfer(to, dest_balance), "ZrxV3Action.trade: dest token transfer failed");
    }
}
