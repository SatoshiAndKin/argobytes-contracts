// SPDX-License-Identifier: MPL-2.0
// TODO: Make this Cloneable by using ArgobytesAuth?
pragma solidity 0.8.5;
pragma abicoder v2;

import {ArgobytesMulticall} from "contracts/ArgobytesMulticall.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";
import {IUniswapV2Callee} from "contracts/external/uniswap/IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "contracts/external/uniswap/IUniswapV2Pair.sol";
import {UniswapV2Library} from "contracts/external/uniswap/UniswapV2Library.sol";

contract ArgobytesUniswapV2Callee is IUniswapV2Callee {
    using SafeERC20 for IERC20;

    address immutable owner;
    address immutable factory;

    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }

    struct CallData {
        ArgobytesMulticall multicall;
        ArgobytesMulticall.Action[] actions;
    }

    function encodeData(ArgobytesMulticall multicall, ArgobytesMulticall.Action[] calldata actions) external view returns (bytes memory data) {
        data = abi.encode(CallData(multicall, actions));
    }

    // gets tokens/WETH via a V2 flash swap, call arbitrary actions, repays V2, and keeps the rest!
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        require(sender == owner, "bad sender");
        require(amount0 == 0 || amount1 == 0, "bad amount"); // this strategy is unidirectional

        address[] memory path = new address[](2);
        {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        require(msg.sender == UniswapV2Library.pairFor(factory, token0, token1), "bad pair"); // ensure that msg.sender is actually a V2 pair
        path[0] = amount0 == 0 ? token0 : token1;
        path[1] = amount0 == 0 ? token1 : token0;
        }
        IERC20 token = IERC20(path[1]);
        uint amount = amount0 + amount1;

        // TODO: remove these
        require(keccak256(bytes(token.symbol())) == keccak256("CRV"), "bad token");
        require(amount >= 100e18, "bad initial amount");

        require(token.balanceOf(address(this)) >= amount, "bad balance");

        // TODO: trace steps are off by 1. balanceOf is fine. its the decode that is failing
        // decode data for multicall
        CallData memory decoded = abi.decode(data, (CallData));

        // transfer all the token to the first action
        token.safeTransfer(decoded.actions[0].target, amount);

        // do arbitrary things with the tokens
        // the actions to be sure to send enough token0 back to pay the flash loan
        decoded.multicall.callActions(decoded.actions);

        uint amountReceived = token.balanceOf(address(this));
        require(amountReceived > amount, "bad amount received");

        uint amountRequired = UniswapV2Library.getAmountsIn(factory, amount, path)[0];
        require(amountReceived > amountRequired, "bad amount required"); // fail if we didn't get enough tokens back to repay our flash loan

        // pay back the flash loan
        token.safeTransfer(msg.sender, amountRequired);
        
        // keep the rest!
        token.safeTransfer(sender, amountReceived - amountRequired);
    }
}
