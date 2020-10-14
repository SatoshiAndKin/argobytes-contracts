// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IERC20, SafeERC20} from "contracts/library/UniversalERC20.sol";
import {
    IUniswapFactory
} from "contracts/interfaces/uniswap/IUniswapFactory.sol";
import {
    IUniswapExchange
} from "contracts/interfaces/uniswap/IUniswapExchange.sol";

contract UniswapV1Action is AbstractERC20Exchange {
    using SafeERC20 for IERC20;

    function tradeEtherToToken(
        address to,
        address exchange,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 trade_gas
    ) external payable returnLeftoverEther() {
        uint256 src_balance = address(this).balance;

        // TODO: what gas limits? https://hackmd.io/@Uniswap/HJ9jLsfTz#Gas-Benchmarks
        trade_gas += 46000;

        // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
        // TODO: get rid of this try. its only here because of "stack too deep"
        // solium-disable-next-line security/no-block-members
        try
            IUniswapExchange(exchange).ethToTokenTransferInput{
                value: src_balance,
                gas: trade_gas
            }(dest_min_tokens, block.timestamp, to)
        returns (uint256 received) {
            // the trade worked!
            // it's fine to trust their returned "received". the msg.sender should check balances at the very end
            require(
                received >= dest_min_tokens,
                "UniswapV1Action.tradeEtherToToken: BAD_EXCHANGE"
            );
        } catch Error(string memory reason) {
            // a revert was called inside ethToTokenTransferInput
            // and a reason string was provided.

            revert(reason);
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside atomicTrade.

            revert("UniswapV1Action.tradeEtherToToken: reverted");
        }
    }

    // TODO: allow trading between 2 factories?
    function tradeTokenToToken(
        address to,
        address exchange,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 trade_gas
    ) external returnLeftoverToken(src_token, exchange) {
        uint256 src_balance = IERC20(src_token).balanceOf(address(this));

        IERC20(src_token).safeApprove(exchange, src_balance);

        // TODO: what gas limits? https://hackmd.io/@Uniswap/HJ9jLsfTz#Gas-Benchmarks
        trade_gas += 140000;

        // tokenToTokenTransferInput(
        //     tokens_sold: uint256,
        //     min_tokens_bought: uint256,
        //     min_eth_bought: uint256,
        //     deadline: uint256,
        //     recipient: address
        //     token_addr: address
        // ): uint256
        // TODO: get rid of this try. its only here because of "stack too deep"
        // solium-disable-next-line security/no-block-members
        try
            IUniswapExchange(exchange).tokenToTokenTransferInput{
                gas: trade_gas
            }(
                src_balance,
                dest_min_tokens,
                1,
                block.timestamp,
                to,
                address(dest_token)
            )
        returns (uint256 received) {
            // the trade worked!
            // it's fine to trust their returned "received". the msg.sender should check balances at the very end
            require(
                received >= dest_min_tokens,
                "UniswapV1Action.tradeTokenToToken: BAD_EXCHANGE"
            );
        } catch Error(string memory reason) {
            // a revert was called inside ethToTokenTransferInput
            // and a reason string was provided.

            revert(
                string(
                    abi.encodePacked(
                        "UniswapV1Action.tradeTokenToToken -> IUniswapExchange.tokenToTokenTransferInput: ",
                        reason
                    )
                )
            );
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside atomicTrade.

            revert(
                "UniswapV1Action.tradeTokenToToken -> IUniswapExchange.tokenToTokenTransferInput: reverted without a reason"
            );
        }
    }

    function tradeTokenToEther(
        address payable to,
        address exchange,
        address src_token,
        uint256 dest_min_tokens,
        uint256 trade_gas
    ) external returnLeftoverToken(src_token, exchange) {
        uint256 src_balance = IERC20(src_token).balanceOf(address(this));

        IERC20(src_token).safeApprove(exchange, src_balance);

        // TODO: what gas limits? https://hackmd.io/@Uniswap/HJ9jLsfTz#Gas-Benchmarks
        trade_gas += 60000;

        // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
        // solium-disable-next-line security/no-block-members
        uint256 received = IUniswapExchange(exchange).tokenToEthTransferInput{
            gas: trade_gas
        }(src_balance, dest_min_tokens, block.timestamp, to);

        // the trade worked!
        // it's fine to trust their returned "received". the msg.sender should check balances at the very end
        require(
            received >= dest_min_tokens,
            "UniswapV1Action.tradeTokenToEther: BAD_EXCHANGE"
        );
    }
}
