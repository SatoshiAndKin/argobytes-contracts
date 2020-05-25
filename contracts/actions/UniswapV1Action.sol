// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/SafeERC20.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {IUniswapFactory} from "interfaces/uniswap/IUniswapFactory.sol";
import {IUniswapExchange} from "interfaces/uniswap/IUniswapExchange.sol";

// TODO: do we want auth on this with setters? i think no. i think we should just have a simple contract with a constructor. if we need changes, we can deploy a new contract. less methods is less attack surface
contract UniswapV1Action is AbstractERC20Exchange {
    using SafeERC20 for IERC20;

    struct UniswapExchangeData {
        address token;
        address factory;
        address exchange;
        uint256 token_supply;
        uint256 ether_supply;
    }

    function getExchange(address factory, address token) internal view returns(IUniswapExchange) {
        return IUniswapExchange(IUniswapFactory(factory).getExchange(token));
    }

    function getAmounts(address token_a, uint256 token_a_amount, address token_b, address factory)
        external view
        returns (Amount[] memory)
    {
        bytes memory extra_data = abi.encode(factory);

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(address maker_token, uint256 taker_wei, address taker_token, bytes memory extra_data)
        public override view 
        returns (Amount memory)
    {
        // TODO: allow multiple factories
        (address factory) = abi.decode(extra_data, (address));

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
            exchange_data[0].token_supply = IERC20(taker_token).balanceOf(address(exchange));
            exchange_data[0].ether_supply = address(exchange).balance;
        } else if (taker_token == ADDRESS_ZERO) {
            // eth to token
            IUniswapExchange exchange = getExchange(factory, maker_token);

            a.maker_wei = exchange.getEthToTokenInputPrice(taker_wei);
            a.selector = this.tradeEtherToToken.selector;
            
            exchange_data = new UniswapExchangeData[](1);
            exchange_data[0].token = maker_token;
            exchange_data[0].factory = factory;
            exchange_data[0].exchange = address(exchange);
            exchange_data[0].token_supply = IERC20(maker_token).balanceOf(address(exchange));
            exchange_data[0].ether_supply = address(exchange).balance;
        } else {
            // token to token
            IUniswapExchange exchange = getExchange(factory, taker_token);

            exchange_data = new UniswapExchangeData[](2);

            a.maker_wei = exchange.getTokenToEthInputPrice(taker_wei);
            exchange_data[0].token = maker_token;
            exchange_data[0].factory = factory;
            exchange_data[0].exchange = address(exchange);
            exchange_data[0].token_supply = IERC20(taker_token).balanceOf(address(exchange));
            exchange_data[0].ether_supply = address(exchange).balance;

            exchange = getExchange(factory, maker_token);

            a.maker_wei = exchange.getEthToTokenInputPrice(a.maker_wei);
            exchange_data[1].token = maker_token;
            exchange_data[1].factory = factory;
            exchange_data[1].exchange = address(exchange);
            exchange_data[1].token_supply = IERC20(maker_token).balanceOf(address(exchange));
            exchange_data[1].ether_supply = address(exchange).balance;

            a.selector = this.tradeTokenToToken.selector;
        }

        // TODO: would be cool to encode the complete calldata, but we can't be sure about the "to" address. we could default to 0x0 and fill it in though
        //a.trade_extra_data = "";

        a.exchange_data = abi.encode(exchange_data);

        return a;
    }

    function tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens, uint dest_max_tokens) external returnLeftoverEther() {
        require(dest_token != ADDRESS_ZERO, "UniswapV1Action.tradeEtherToToken: dest_token cannot be ETH");

        uint srcBalance = address(this).balance;

        require(srcBalance > 0, "UniswapV1Action.tradeEtherToToken: NO_BALANCE");

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "UniswapV1Action.tradeEtherToToken: SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens?

            // def ethToTokenTransferOutput(tokens_bought: uint256, deadline: timestamp, recipient: address) -> uint256(wei):
            // solium-disable-next-line security/no-block-members
            uint received = IUniswapExchange(exchange).ethToTokenTransferOutput{value: srcBalance}(dest_max_tokens, block.timestamp, to);

            require(received > 0, "UniswapV1Action.tradeEtherToToken: BAD_EXCHANGE");
        // TODO: should this "else" be "else if (dest_min_tokens > 0)"? less gas to just use an else. who cares if they passed 0 for dest_min_tokens. maybe slippage doesn't matter for their use
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
            require(dest_min_tokens > 0, "UniswapV1Action.tradeEtherToToken: dest_min_tokens should not == 0");

            // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
            // solium-disable-next-line security/no-block-members
            uint received = IUniswapExchange(exchange).ethToTokenTransferInput{value: srcBalance}(dest_min_tokens, block.timestamp, to);

            require(received > 0, "UniswapV1Action.tradeEtherToToken: BAD_EXCHANGE");
        }
    }

    // TODO: allow trading between 2 factories?
    function tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens) external returnLeftoverToken(src_token, exchange) {
        require(src_token != ADDRESS_ZERO, "UniswapV1Action.tradeTokenToToken: src_token cannot be ETH");
        require(dest_token != ADDRESS_ZERO, "UniswapV1Action.tradeTokenToToken: dest_token cannot be ETH");

        uint src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "UniswapV1Action.tradeTokenToToken: NO_BALANCE");

        IERC20(src_token).safeApprove(exchange, src_balance);

        if (to == ADDRESS_ZERO) {
            to = msg.sender;
        }

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "UniswapV1Action.tradeTokenToToken: SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens instead?

            // TODO: how should we calculate this? tokenToEthSomething? or is it fine to use a very large amount?
            // TODO: gas golf this
            uint max_eth_sold = uint(-1);

            // tokenToTokenTransferOutput(
            //     tokens_bought: uint256,
            //     max_tokens_sold: uint256,
            //     max_eth_sold: uint256,
            //     deadline: uint256,
            //     recipient: address,
            //     token_addr: address
            // ): uint256
            // solium-disable-next-line security/no-block-members
            IUniswapExchange(exchange).tokenToTokenTransferOutput(dest_max_tokens, src_balance, max_eth_sold, block.timestamp, to, dest_token);

            // require(received > 0, "UniswapV1Action.tradeTokenToToken: BAD_EXCHANGE");
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
            require(dest_min_tokens > 0, "UniswapV1Action.tradeTokenToToken: dest_min_tokens should not == 0");

            // TODO: how should we calculate this? tokenToEthSomething? or is it fine to use 1
            uint min_eth_bought = 1;

            // tokenToTokenTransferInput(
            //     tokens_sold: uint256,
            //     min_tokens_bought: uint256,
            //     min_eth_bought: uint256,
            //     deadline: uint256,
            //     recipient: address
            //     token_addr: address
            // ): uint256
            // solium-disable-next-line security/no-block-members
            IUniswapExchange(exchange).tokenToTokenTransferInput(src_balance, dest_min_tokens, min_eth_bought, block.timestamp, to, address(dest_token));

            // require(received > 0, "UniswapV1Action.tradeTokenToToken: BAD_EXCHANGE");
        }
    }

    function tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens, uint dest_max_tokens) external returnLeftoverToken(src_token, exchange) {
        require(src_token != ADDRESS_ZERO, "UniswapV1Action.tradeTokenToEther: src_token cannot be ETH");

        uint src_balance = IERC20(src_token).balanceOf(address(this));
        require(src_balance > 0, "UniswapV1Action.tradeTokenToEther: NO_BALANCE");

        IERC20(src_token).safeApprove(exchange, src_balance);

        if (dest_max_tokens > 0) {
            require(dest_min_tokens == 0, "UniswapV1Action.tradeTokenToEther: SET_MIN_OR_MAX");  // TODO: do something with dest_min_tokens?

            // def tokenToEthTransferOutput(eth_bought: uint256(wei), max_tokens: uint256, deadline: timestamp, recipient: address) -> uint256:
            // solium-disable-next-line security/no-block-members
            uint received = IUniswapExchange(exchange).tokenToEthTransferOutput(dest_max_tokens, src_balance, block.timestamp, to);

            require(received > 0, "UniswapV1Action.tradeTokenToEther: BAD_EXCHANGE");
        } else {
            // dest_max_tokens is 0
            // dest_min_tokens may be 1, but is probably set to something to protect against large slippage in price
            require(dest_min_tokens > 0, "UniswapV1Action.tradeTokenToEther: dest_min_tokens should not == 0");

            // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
            // solium-disable-next-line security/no-block-members
            uint received = IUniswapExchange(exchange).tokenToEthTransferInput(src_balance, dest_min_tokens, block.timestamp, to);

            require(received > 0, "UniswapV1Action.tradeTokenToEther: BAD_EXCHANGE");
        }
    }
}
