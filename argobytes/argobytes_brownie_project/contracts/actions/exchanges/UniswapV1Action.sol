// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IERC20} from "contracts/library/UniversalERC20.sol";

import {IUniswapExchange} from "contracts/external/uniswap/IUniswapExchange.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

contract UniswapV1Action is AbstractERC20Exchange {
    // this function must be able to receive ether if it is expected to trade it
    receive() external payable {}

    function tradeEtherToToken(
        address to,
        IUniswapExchange exchange,
        address dest_token,
        uint256 dest_min_tokens
    ) external payable {
        // leave 1 wei behind for gas savings on future calls
        // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
        // solium-disable-next-line security/no-block-members
        exchange.ethToTokenTransferInput{value: address(this).balance - 1}(dest_min_tokens, block.timestamp, to);
    }

    // TODO: allow trading between 2 factories?
    function tradeTokenToToken(
        address to,
        address exchange,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens
    ) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 src_balance = IERC20(src_token).balanceOf(address(this)) - 1;

        // some contracts do all sorts of fancy approve from 0 checks to avoid front running issues. I really don't see the benefit here
        IERC20(src_token).approve(exchange, src_balance);

        // tokenToTokenTransferInput(
        //     tokens_sold: uint256,
        //     min_tokens_bought: uint256,
        //     min_eth_bought: uint256,
        //     deadline: uint256,
        //     recipient: address
        //     token_addr: address
        // ): uint256
        // solium-disable-next-line security/no-block-members
        IUniswapExchange(exchange).tokenToTokenTransferInput(
            src_balance,
            dest_min_tokens,
            1, // TODO: do we care about min eth bought?
            block.timestamp,
            to,
            dest_token
        );
    }

    function tradeTokenToEther(
        address payable to,
        address exchange,
        address src_token,
        uint256 dest_min_tokens
    ) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 src_balance = IERC20(src_token).balanceOf(address(this)) - 1;

        IERC20(src_token).approve(exchange, src_balance);

        // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
        // solium-disable-next-line security/no-block-members
        IUniswapExchange(exchange).tokenToEthTransferInput(src_balance, dest_min_tokens, block.timestamp, to);
    }
}
