// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {
    IUniswapFactory
} from "contracts/interfaces/uniswap/IUniswapFactory.sol";
import {
    IUniswapExchange
} from "contracts/interfaces/uniswap/IUniswapExchange.sol";

contract UniswapV1Action is AbstractERC20Exchange {
    struct UniswapExchangeData {
        address token;
        address factory;
        address exchange;
        uint256 token_supply;
        uint256 ether_supply;
        bytes4 token_to_token_selector;
    }

    function getExchange(address factory, address token)
        public
        view
        returns (IUniswapExchange)
    {
        return IUniswapExchange(IUniswapFactory(factory).getExchange(token));
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b,
        address factory
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = abi.encode(factory);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_token,
        uint256 taker_wei,
        address taker_token,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        // TODO: allow multiple factories
        address factory = abi.decode(extra_data, (address));

        Amount memory a = newPartialAmount(maker_token, taker_wei, taker_token);
        UniswapExchangeData[] memory exchange_data;

        // TODO: this only works with input amounts. do we want it to work with output amounts?
        if (maker_token == ADDRESS_ZERO) {
            // token to eth
            IUniswapExchange exchange = getExchange(factory, taker_token);

            a.maker_wei = exchange.getTokenToEthInputPrice(taker_wei);
            a.selector = this.tradeTokenToEther.selector;

            exchange_data = new UniswapExchangeData[](1);
            exchange_data[0].token = taker_token;
            exchange_data[0].factory = factory;
            exchange_data[0].exchange = address(exchange);
            exchange_data[0].token_supply = IERC20(taker_token).balanceOf(
                address(exchange)
            );
            exchange_data[0].ether_supply = address(exchange).balance;
            exchange_data[0].token_to_token_selector = this
                .tradeTokenToToken
                .selector;
        } else if (taker_token == ADDRESS_ZERO) {
            // eth to token
            IUniswapExchange exchange = getExchange(factory, maker_token);

            a.maker_wei = exchange.getEthToTokenInputPrice(taker_wei);
            a.selector = this.tradeEtherToToken.selector;

            exchange_data = new UniswapExchangeData[](1);
            exchange_data[0].token = maker_token;
            exchange_data[0].factory = factory;
            exchange_data[0].exchange = address(exchange);
            exchange_data[0].token_supply = IERC20(maker_token).balanceOf(
                address(exchange)
            );
            exchange_data[0].ether_supply = address(exchange).balance;
            exchange_data[0].token_to_token_selector = this
                .tradeTokenToToken
                .selector;
        } else {
            // token to token
            IUniswapExchange exchange = getExchange(factory, taker_token);

            exchange_data = new UniswapExchangeData[](2);

            a.maker_wei = exchange.getTokenToEthInputPrice(taker_wei);
            exchange_data[0].token = maker_token;
            exchange_data[0].factory = factory;
            exchange_data[0].exchange = address(exchange);
            exchange_data[0].token_supply = IERC20(taker_token).balanceOf(
                address(exchange)
            );
            exchange_data[0].ether_supply = address(exchange).balance;

            exchange = getExchange(factory, maker_token);

            a.maker_wei = exchange.getEthToTokenInputPrice(a.maker_wei);
            exchange_data[1].token = maker_token;
            exchange_data[1].factory = factory;
            exchange_data[1].exchange = address(exchange);
            exchange_data[1].token_supply = IERC20(maker_token).balanceOf(
                address(exchange)
            );
            exchange_data[1].ether_supply = address(exchange).balance;

            a.selector = this.tradeTokenToToken.selector;
        }

        //a.trade_extra_data = "";

        a.exchange_data = abi.encode(exchange_data);

        return a;
    }

    function token_supported(address exchange, address token)
        public
        override
        returns (bool)
    {
        revert("wip");
    }

    function tradeEtherToToken(
        address to,
        address exchange,
        address dest_token,
        uint256 dest_min_tokens,
        uint256 trade_gas
    ) external payable returnLeftoverEther() {
        require(
            dest_token != ADDRESS_ZERO,
            "UniswapV1Action.tradeEtherToToken: dest_token cannot be ETH"
        );
        // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
        require(
            dest_min_tokens > 0,
            "UniswapV1Action.tradeEtherToToken: dest_min_tokens should not == 0"
        );

        uint256 src_balance = address(this).balance;

        require(
            src_balance > 0,
            "UniswapV1Action.tradeEtherToToken: NO_BALANCE"
        );

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        // TODO: what gas limits? https://hackmd.io/@Uniswap/HJ9jLsfTz#Gas-Benchmarks
        trade_gas += 46000;

        // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
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

            revert(
                string(
                    abi.encodePacked(
                        "UniswapV1Action.tradeEtherToToken -> IUniswapExchange.ethToTokenTransferInput: ",
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
                "UniswapV1Action.tradeEtherToToken -> IUniswapExchange.ethToTokenTransferInput: reverted without a reason"
            );
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
        require(
            src_token != ADDRESS_ZERO,
            "UniswapV1Action.tradeTokenToToken: src_token cannot be ETH"
        );
        require(
            dest_token != ADDRESS_ZERO,
            "UniswapV1Action.tradeTokenToToken: dest_token cannot be ETH"
        );
        // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
        require(
            dest_min_tokens > 0,
            "UniswapV1Action.tradeTokenToToken: dest_min_tokens should not == 0"
        );

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(
            src_balance > 0,
            "UniswapV1Action.tradeTokenToToken: NO_BALANCE"
        );

        IERC20(src_token).approve(exchange, src_balance);

        // TODO: what gas limits? https://hackmd.io/@Uniswap/HJ9jLsfTz#Gas-Benchmarks
        trade_gas += 140000;

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        // tokenToTokenTransferInput(
        //     tokens_sold: uint256,
        //     min_tokens_bought: uint256,
        //     min_eth_bought: uint256,
        //     deadline: uint256,
        //     recipient: address
        //     token_addr: address
        // ): uint256
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
        require(
            src_token != ADDRESS_ZERO,
            "UniswapV1Action.tradeTokenToEther: src_token cannot be ETH"
        );
        // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
        require(
            dest_min_tokens > 0,
            "UniswapV1Action.tradeTokenToEther: dest_min_tokens should not == 0"
        );

        uint256 src_balance = IERC20(src_token).balanceOf(address(this));
        require(
            src_balance > 0,
            "UniswapV1Action.tradeTokenToEther: NO_BALANCE"
        );

        IERC20(src_token).approve(exchange, src_balance);

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        // TODO: what gas limits? https://hackmd.io/@Uniswap/HJ9jLsfTz#Gas-Benchmarks
        trade_gas += 60000;

        // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
        // solium-disable-next-line security/no-block-members
        try
            IUniswapExchange(exchange).tokenToEthTransferInput{gas: trade_gas}(
                src_balance,
                dest_min_tokens,
                block.timestamp,
                to
            )
        returns (uint256 received) {
            // the trade worked!
            // it's fine to trust their returned "received". the msg.sender should check balances at the very end
            require(
                received >= dest_min_tokens,
                "UniswapV1Action.tradeTokenToEther: BAD_EXCHANGE"
            );
        } catch Error(string memory reason) {
            // a revert was called inside ethToTokenTransferInput
            // and a reason string was provided.

            revert(
                string(
                    abi.encodePacked(
                        "UniswapV1Action.tradeTokenToEther -> IUniswapExchange.tokenToEthTransferInput: ",
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
                "UniswapV1Action.tradeTokenToEther -> IUniswapExchange.tokenToEthTransferInput: reverted without a reason"
            );
        }
    }
}
