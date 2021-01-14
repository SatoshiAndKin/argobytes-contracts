// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {
    IKyberNetworkProxy
} from "contracts/interfaces/kyber/IKyberNetworkProxy.sol";
import {IERC20} from "contracts/library/UniversalERC20.sol";

contract KyberAction is AbstractERC20Exchange {
    // TODO: document MAX_QTY
    uint256 internal constant MAX_QTY = 10**28;

    IERC20 internal constant ETH_ON_KYBER = IERC20(
        0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    );

    // TODO: do we really want this in state?
    // generally i prefer not to have any state, but if someone uses my contract, i'd like some credit
    // TODO: does setting wallet_id but not setting a platform fee do anything? i think we still get something
    // TODO: should we set a platform fee? we aren't adding much value here
    address payable _platform_wallet;

    constructor(address payable platform_wallet) {
        _platform_wallet = platform_wallet;
    }

    // TODO: helpers for creating "hints"

    /*
    This could have fancier auth on it, but I don't think its worth the
    */
    function setPlatformWallet(address payable platform_wallet) public {
        require(
            msg.sender == _platform_wallet,
            "KyberAction.setPlatformWallet: 403"
        );

        _platform_wallet = platform_wallet;
    }

    function tradeEtherToToken(
        address network_proxy,
        address payable to,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata hint
    ) public payable {
        uint256 src_amount = address(this).balance;

        // require(src_amount > 0, "KyberAction.tradeEtherToToken: no src_amount");

        uint256 received = IKyberNetworkProxy(network_proxy).tradeWithHintAndFee{
            value: src_amount
        }(
            ETH_ON_KYBER,
            src_amount,
            IERC20(dest_token),
            to,
            MAX_QTY,
            1, // minConversionRate of 1 will execute the trade according to market price
            _platform_wallet,
            0,
            hint
        );

        // TODO: set minConversionRate instead?
        require(
            received >= dest_min_tokens,
            "KyberAction.tradeEtherToToken: FAILED_TRADE"
        );
    }

    function tradeTokenToToken(
        address network_proxy,
        address payable to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata hint
    ) external {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));

        // require(src_amount > 0, "KyberAction.tradeTokenToToken: no src_amount");

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).approve(network_proxy, src_amount);

        uint256 received = IKyberNetworkProxy(network_proxy).tradeWithHintAndFee(
            IERC20(src_token),
            src_amount,
            IERC20(dest_token),
            to,
            MAX_QTY,
            1, // minConversionRate of 1 will execute the trade according to market price
            _platform_wallet,
            0,
            hint
        );

        // TODO: set minConversionRate instead?
        require(
            received >= dest_min_tokens,
            "KyberAction.tradeTokenToToken: FAILED_TRADE"
        );
    }

    function tradeTokenToEther(
        address network_proxy,
        address payable to,
        address src_token,
        uint256 dest_min_tokens,
        bytes calldata hint
    ) external returnLeftoverToken(src_token) {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));

        // require(src_amount > 0, "KyberAction.tradeTokenToEther: no src_amount");

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).approve(network_proxy, src_amount);

        uint256 received = IKyberNetworkProxy(network_proxy).tradeWithHintAndFee(
            IERC20(src_token),
            src_amount,
            ETH_ON_KYBER,
            to,
            MAX_QTY,
            1, // minConversionRate of 1 will execute the trade according to market price
            _platform_wallet,
            0,
            hint
        );

        // TODO: set minConversionRate instead?
        require(
            received >= dest_min_tokens,
            "KyberAction.tradeTokenToEther: FAILED_TRADE"
        );
    }
}
