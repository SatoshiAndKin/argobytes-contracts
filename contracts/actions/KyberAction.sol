// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {ArgobytesERC20} from "contracts/library/ArgobytesERC20.sol";
import {
    IKyberNetworkProxy
} from "contracts/interfaces/kyber/IKyberNetworkProxy.sol";
import {IERC20, UniversalERC20, SafeERC20} from "contracts/library/UniversalERC20.sol";

contract KyberAction is AbstractERC20Exchange {
    using ArgobytesERC20 for IERC20;
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    // TODO: document MAX_QTY
    uint256 internal constant MAX_QTY = 10**28;
    IERC20 internal constant ETH_ON_KYBER = IERC20(
        0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    );

    // TODO: do we really want this in state?
    address _wallet_id;

    constructor(address wallet_id) {
        _wallet_id = wallet_id;
    }

    function setWalletId(address wallet_id) public {
        require(
            msg.sender == _wallet_id,
            "KyberAction.setWalletId: access denied"
        );

        _wallet_id = wallet_id;
    }

    function tradeEtherToToken(
        address network_proxy,
        address to,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens
    ) public payable returnLeftoverEther() {
        require(
            dest_token != ADDRESS_ZERO,
            "KyberAction.tradeEtherToToken: dest_token cannot be ADDRESS_ZERO"
        );
        require(
            IERC20(dest_token) != ETH_ON_KYBER,
            "KyberAction.tradeEtherToToken: dest_token cannot be ETH"
        );

        uint256 src_amount = address(this).balance;

        require(src_amount > 0, "KyberAction.tradeEtherToToken: NO_SRC_AMOUNT");

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }

        uint256 received = IKyberNetworkProxy(network_proxy).trade{
            value: src_amount
        }(
            ETH_ON_KYBER,
            src_amount,
            IERC20(dest_token),
            to,
            dest_max_tokens,
            1, // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        require(
            received >= dest_min_tokens,
            "KyberAction._tradeTokenToToken: FAILED_TRADE"
        );
    }

    function tradeTokenToToken(
        address network_proxy,
        address to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens
    ) external returnLeftoverToken(src_token) {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(
            src_amount > 0,
            "KyberAction._tradeTokenToToken: NO_SOURCE_AMOUNT"
        );

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).excessiveApprove(network_proxy, src_amount);

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }

        uint256 received = IKyberNetworkProxy(network_proxy).trade(
            IERC20(src_token),
            src_amount,
            IERC20(dest_token),
            to,
            dest_max_tokens,
            1, // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        require(
            received >= dest_min_tokens,
            "KyberAction._tradeTokenToToken: FAILED_TRADE"
        );
    }

    function tradeTokenToEther(
        address network_proxy,
        address to,
        address src_token,
        uint256 dest_min_tokens,
        uint256 dest_max_tokens
    ) external returnLeftoverToken(src_token) {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(
            src_amount > 0,
            "KyberAction._tradeTokenToEther: NO_SOURCE_AMOUNT"
        );

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).excessiveApprove(network_proxy, src_amount);

        if (dest_max_tokens == 0) {
            dest_max_tokens = MAX_QTY;
        }

        uint256 received = IKyberNetworkProxy(network_proxy).trade(
            IERC20(src_token),
            src_amount,
            ETH_ON_KYBER,
            to,
            dest_max_tokens,
            1, // minConversionRate of 1 will execute the trade according to market price
            _wallet_id
        );

        require(
            received >= dest_min_tokens,
            "KyberAction._tradeTokenToEther: FAILED_TRADE"
        );
    }
}
