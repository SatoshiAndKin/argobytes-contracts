// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

import {IERC20} from "contracts/external/erc20/IERC20.sol";
import {IKyberNetworkProxy} from "contracts/external/kyber/IKyberNetworkProxy.sol";
import {IKyberRegisterWallet} from "contracts/external/kyber/IKyberRegisterWallet.sol";

error AccessDenied();
error FailedTrade();

contract KyberAction is AbstractERC20Exchange {
    // TODO: document MAX_QTY
    uint256 internal constant MAX_QTY = 10**28;

    IKyberRegisterWallet internal constant KYBER_REGISTER_WALLET =
        IKyberRegisterWallet(0xECa04bB23612857650D727B8ed008f80952654ee);
    IERC20 internal constant ETH_ON_KYBER = IERC20(address(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee));

    IKyberNetworkProxy immutable network_proxy;
    address payable immutable platform_wallet;

    // this function must be able to receive ether if it is expected to trade it
    receive() external payable {}

    constructor(IKyberNetworkProxy _network_proxy, address payable _platform_wallet) {
        network_proxy = _network_proxy;

        KYBER_REGISTER_WALLET.registerWallet(_platform_wallet);

        platform_wallet = _platform_wallet;
    }

    // TODO: helpers for creating "hints"
    function tradeEtherToToken(
        address payable to,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata hint
    ) public payable {
        // leave 1 wei behind for gas savings on future calls
        uint256 src_amount = address(this).balance - 1;

        uint256 received = network_proxy.tradeWithHintAndFee{value: src_amount}(
            ETH_ON_KYBER,
            src_amount,
            IERC20(dest_token),
            to,
            MAX_QTY,
            1, // minConversionRate of 1 will execute the trade according to market price
            platform_wallet,
            0,
            hint
        );

        // TODO: set minConversionRate instead?
        require(received >= dest_min_tokens, "KyberAction.tradeEtherToToken: FAILED_TRADE");
    }

    function tradeTokenToToken(
        address payable to,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        bytes calldata hint
    ) external {
        // Use the full balance of tokens transferred from the trade executor
        // leave 1 wei behind for gas savings on future calls
        uint256 src_amount = IERC20(src_token).balanceOf(address(this)) - 1;

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).approve(address(network_proxy), src_amount);

        uint256 received = network_proxy.tradeWithHintAndFee(
            IERC20(src_token),
            src_amount,
            IERC20(dest_token),
            to,
            MAX_QTY,
            1, // minConversionRate of 1 will execute the trade according to market price
            platform_wallet,
            0,
            hint
        );

        // TODO: set minConversionRate instead?
        if (received < dest_min_tokens) {
            revert FailedTrade();
        }
    }

    function tradeTokenToEther(
        address payable to,
        address src_token,
        uint256 dest_min_tokens,
        bytes calldata hint
    ) external {
        // Use the full balance of tokens transferred from the trade executor
        // leave 1 wei behind for gas savings on future calls
        uint256 src_amount = IERC20(src_token).balanceOf(address(this)) - 1;

        // require(src_amount > 0, "KyberAction.tradeTokenToEther: no src_amount");

        // Approve the exchange to transfer tokens from this contract to the reserve
        IERC20(src_token).approve(address(network_proxy), src_amount);

        uint256 received = network_proxy.tradeWithHintAndFee(
            IERC20(src_token),
            src_amount,
            ETH_ON_KYBER,
            to,
            MAX_QTY,
            1, // minConversionRate of 1 will execute the trade according to market price
            platform_wallet,
            0,
            hint
        );

        // TODO: set minConversionRate instead?
        require(received >= dest_min_tokens, "KyberAction.tradeTokenToEther: FAILED_TRADE");
    }
}
