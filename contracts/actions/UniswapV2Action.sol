// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {ArgobytesERC20} from "contracts/library/ArgobytesERC20.sol";
import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {
    IUniswapV2Router01
} from "contracts/interfaces/uniswap/IUniswapV2Router01.sol";
import {IUniswapV2Pair} from "contracts/interfaces/uniswap/IUniswapV2Pair.sol";

contract UniswapV2Action is AbstractERC20Exchange {
    // TODO: trading
    // TODO: flash loans
}
