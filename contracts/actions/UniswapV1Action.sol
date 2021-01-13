// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {ArgobytesERC20} from "contracts/library/ArgobytesERC20.sol";
import {IERC20, SafeERC20} from "contracts/library/UniversalERC20.sol";
import {
    IUniswapFactory
} from "contracts/interfaces/uniswap/IUniswapFactory.sol";
import {
    IUniswapExchange
} from "contracts/interfaces/uniswap/IUniswapExchange.sol";

contract UniswapV1Action is AbstractERC20Exchange {
    using ArgobytesERC20 for IERC20;
    using SafeERC20 for IERC20;

    /* just in case some token approve gets stuck */
    function clearApproval(
        address token,
        address who
    ) external {
        IERC20(token).approve(who, 0);
    }

    function tradeEtherToToken(
        address to,
        address exchange,
        address dest_token,
        uint256 dest_min_tokens
    ) external payable {
        // def ethToTokenTransferInput(min_tokens: uint256, deadline: timestamp, recipient: address) -> uint256
        // solium-disable-next-line security/no-block-members
        IUniswapExchange(exchange).ethToTokenTransferInput{
            value: address(this).balance
        }(dest_min_tokens, block.timestamp, to);
    }

    // TODO: allow trading between 2 factories?
    function tradeTokenToToken(
        address to,
        address exchange,
        address src_token,
        address dest_token,
        uint256 dest_min_tokens
    ) external {
        uint256 src_balance = IERC20(src_token).balanceOf(address(this));

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
            1,
            block.timestamp,
            to,
            address(dest_token)
        );
    }

    function tradeTokenToEther(
        address payable to,
        address exchange,
        address src_token,
        uint256 dest_min_tokens
    ) external {
        uint256 src_balance = IERC20(src_token).balanceOf(address(this));

        IERC20(src_token).approve(exchange, src_balance);

        // def tokenToEthTransferInput(tokens_sold: uint256, min_eth: uint256(wei), deadline: timestamp, recipient: address) -> uint256(wei):
        // solium-disable-next-line security/no-block-members
        IUniswapExchange(exchange).tokenToEthTransferInput(src_balance, dest_min_tokens, block.timestamp, to);
    }
}
