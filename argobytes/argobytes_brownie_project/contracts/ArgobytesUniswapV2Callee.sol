// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.5;
pragma abicoder v2;

import {IWETH9} from "contracts/external/weth9/IWETH9.sol";
import {IUniswapV2Router01} from "contracts/external/uniswap/IUniswapV2Router01.sol";
import {IUniswapV2Callee} from "contracts/external/uniswap/IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "contracts/external/uniswap/IUniswapV2Pair.sol";
import {UniswapV2Library} from "contracts/external/uniswap/UniswapV2Library.sol";
import {ArgobytesMulticall} from "contracts/ArgobytesMulticall.sol";

import {IERC20, SafeERC20} from "@OpenZeppelin/token/ERC20/utils/SafeERC20.sol";

contract ArgobytesUniswapV2Callee is IUniswapV2Callee {
    using SafeERC20 for IERC20;

    address immutable factory;
    IWETH9 immutable WETH;

    constructor(IUniswapV2Router01 _router) {
        factory = _router.factory();
        WETH = IWETH9(_router.WETH());
    }

    struct CallData {
        ArgobytesMulticall multicall;
        ArgobytesMulticall.Action[] actions;
    }

    function encodeData(address multicall, ArgobytesMulticall.Action[] calldata actions) external view returns (bytes memory data) {
        data = abi.encode(multicall, actions);
    }

    // gets tokens/WETH via a V2 flash swap, call arbitrary actions, repays V2, and keeps the rest!
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        assert(amount0 == 0 || amount1 == 0); // this strategy is unidirectional

        address[] memory path = new address[](2);
        {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        assert(msg.sender == UniswapV2Library.pairFor(factory, token0, token1)); // ensure that msg.sender is actually a V2 pair
        path[0] = amount0 == 0 ? token0 : token1;
        path[1] = amount0 == 0 ? token1 : token0;
        }
        IERC20 token = IERC20(path[1]);
        uint amount = amount0 + amount1;

        // decode data for multicall
        CallData memory decoded = abi.decode(data, (CallData));

        // transfer all the token to the first action
        token.transfer(decoded.actions[0].target, amount);

        // do arbitrary things with the tokens
        // the actions to be sure to send enough token0 back to pay the flash loan
        decoded.multicall.callActions(decoded.actions);

        uint amountReceived = IERC20(path[1]).balanceOf(address(this));
        uint amountRequired = UniswapV2Library.getAmountsIn(factory, amount, path)[0];

        assert(amountReceived > amountRequired); // fail if we didn't get enough tokens back to repay our flash loan

        // pay back the flash loan
        token.safeTransfer(msg.sender, amountRequired);

        // keep the rest!
        token.safeTransfer(sender, amountReceived - amountRequired);
    }
}
