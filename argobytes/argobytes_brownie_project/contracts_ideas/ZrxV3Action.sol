// SPDX-License-Identifier: MPL-2.0
// https://0x.org/docs/guides/v3-forwarder-specification#marketsellorderswitheth
// https://0x.org/docs/guides/introduction-to-using-0x-liquidity-in-smart-contracts#introduction-to-using-0x-liquidity-in-smart-contracts
// https://0x.org/docs/guides/use-0x-api-liquidity-in-your-smart-contracts
pragma solidity 0.8.7;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {UniversalERC20, IERC20} from "contracts/library/UniversalERC20.sol";
import {AbstractERC20Modifiers} from "./AbstractERC20Exchange.sol";

contract ZrxV3Action is AbstractERC20Modifiers {
    using Address for address;
    using UniversalERC20 for IERC20;

    // TODO: should we trade against the exchange contract or the forwarder contract?
    function tradeEth(
        address zrx_forwarder,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes memory zrx_data
    ) external payable returnLeftoverUniversal(src_token, zrx_forwarder) {
        uint256 src_balance = IERC20(src_token).universalBalanceOf(
            address(this)
        );

        IERC20(src_token).universalApprove(zrx_forwarder, src_balance);
        // TODO: approveMakerAssetProxy?

        // TODO: use the actual interface?
        // TODO: better error message?
        zrx_forwarder.functionCallWithValue(
            zrx_data,
            src_balance,
            "0x Forwarder call failed"
        );

        uint256 dest_balance = IERC20(dest_token).universalBalanceOf(
            address(this)
        );

        require(
            dest_balance >= dest_min_tokens,
            "ZrxV3Action.trade: not enough destination token received"
        );

        IERC20(dest_token).universalTransfer(to, dest_balance);
    }
}
