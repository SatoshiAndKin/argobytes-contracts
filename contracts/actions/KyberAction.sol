// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {
    IKyberNetworkProxy
} from "contracts/interfaces/kyber/IKyberNetworkProxy.sol";
import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20, UniversalERC20, SafeERC20} from "contracts/library/UniversalERC20.sol";

contract KyberAction is AbstractERC20Exchange {
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    // TODO: document MAX_QTY
    uint256 internal constant MAX_QTY = 10**28;
    IERC20 internal constant ETH_ON_KYBER = IERC20(
        0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    );

    address _wallet_id;

    constructor() {
        _wallet_id = msg.sender;
    }

    function setWalletId(address wallet_id) public {
        require(
            msg.sender == _wallet_id,
            "KyberAction.setWalletId: access denied"
        );

        _wallet_id = wallet_id;
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b,
        address network_proxy
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = abi.encode(network_proxy);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_token,
        uint256 taker_wei,
        address taker_token,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        address network_proxy = abi.decode(extra_data, (address));

        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);

        uint256 expected_rate;

        // TODO: this only works with input amounts. do we want it to work with output amounts?
        if (maker_token == ADDRESS_ZERO) {
            // token to eth
            (expected_rate, ) = IKyberNetworkProxy(network_proxy)
                .getExpectedRate(IERC20(taker_token), ETH_ON_KYBER, taker_wei);
            a.selector = this.tradeTokenToEther.selector;
        } else if (taker_token == ADDRESS_ZERO) {
            // eth to token
            (expected_rate, ) = IKyberNetworkProxy(network_proxy)
                .getExpectedRate(ETH_ON_KYBER, IERC20(maker_token), taker_wei);
            a.selector = this.tradeEtherToToken.selector;
        } else {
            // token to token
            (expected_rate, ) = IKyberNetworkProxy(network_proxy)
                .getExpectedRate(
                IERC20(taker_token),
                IERC20(maker_token),
                taker_wei
            );
            a.selector = this.tradeTokenToToken.selector;
        }

        // TODO: disable the uniswap reserve? https://github.com/CryptoManiacsZone/1split/blob/614fa1efdd647d560491671c92869daf69f158b0/contracts/OneSplitBase.sol#L532

        uint256 maker_decimals = IERC20(maker_token).universalDecimals();
        uint256 taker_decimals = IERC20(taker_token).universalDecimals();

        // https://developer.kyber.network/docs/API_ABI-TokenQuantityConversion/#calcdstqty
        // https://github.com/KyberNetwork/smart-contracts/blob/master/contracts/Utils2.sol#L28
        uint256 precision = 10**18;

        // TODO: this is on Kyber's Utils2 contract. use that instead of re-implementing here
        if (maker_decimals >= taker_decimals) {
            // (srcQty * rate * (10**(dstDecimals - srcDecimals))) / PRECISION;
            expected_rate =
                (taker_wei *
                    expected_rate *
                    (10**(maker_decimals - taker_decimals))) /
                precision;
        } else {
            // (srcQty * rate) / (PRECISION * (10**(srcDecimals - dstDecimals)));
            expected_rate =
                (taker_wei * expected_rate) /
                (precision * (10**(taker_decimals - maker_decimals)));
        }

        // TODO: use slippage_rate?
        a.maker_wei = expected_rate;
        //a.trade_extra_data = "";

        return a;
    }

    function token_supported(address exchange, address token)
        public
        returns (bool)
    {
        revert("wip");
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
    ) external returnLeftoverToken(src_token, network_proxy) {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(
            src_amount > 0,
            "KyberAction._tradeTokenToToken: NO_SOURCE_AMOUNT"
        );

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).safeApprove(network_proxy, src_amount);

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
    ) external returnLeftoverToken(src_token, network_proxy) {
        // Use the full balance of tokens transferred from the trade executor
        uint256 src_amount = IERC20(src_token).balanceOf(address(this));
        require(
            src_amount > 0,
            "KyberAction._tradeTokenToEther: NO_SOURCE_AMOUNT"
        );

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).safeApprove(network_proxy, src_amount);

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
