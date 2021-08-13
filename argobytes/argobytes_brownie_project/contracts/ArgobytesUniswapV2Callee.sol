// SPDX-License-Identifier: MPL-2.0
// TODO: Make this Cloneable by using ArgobytesAuth?
pragma solidity 0.8.5;
pragma abicoder v2;

import {ArgobytesMulticallInternal} from "contracts/ArgobytesMulticall.sol";
import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";
import {IUniswapV2Callee} from "contracts/external/uniswap/IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "contracts/external/uniswap/IUniswapV2Pair.sol";
import {UniswapV2Library} from "contracts/external/uniswap/UniswapV2Library.sol";

contract ArgobytesUniswapV2Callee is ArgobytesMulticallInternal, IUniswapV2Callee {
    using SafeERC20 for IERC20;

    address immutable owner;
    address immutable factory;

    error Debugging(uint fee);

    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }

    function encodeData(Action[] calldata actions) external view returns (bytes memory data) {
        data = abi.encode(actions);
    }

    // gets tokens/WETH via a V2 flash swap, call arbitrary actions, repays V2, and keeps the rest!
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        require(sender == owner, "bad sender");  // very basic calldata stealing protection
        require(amount0 == 0 || amount1 == 0, "bad amount"); // this strategy is unidirectional

        IERC20 token;
        // address[] memory path = new address[](2);
        {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        require(msg.sender == UniswapV2Library.pairFor(factory, token0, token1), "bad pair"); // ensure that msg.sender is actually a V2 pair
        // path[0] = amount0 == 0 ? token0 : token1;
        // path[1] = amount0 == 0 ? token1 : token0;
        token = IERC20(amount0 == 0 ? token1 : token0);
        }
        uint amount = amount0 + amount1;

        // decode data for multicall
        Action[] memory actions = abi.decode(data, (Action[]));

        // transfer all the token to the first action
        token.safeTransfer(actions[0].target, amount);

        // do arbitrary things with the tokens
        // the actions must send enough token back here to pay the flash loan
        // TODO: lets just make a test thta doessn't do full trades and instead just sweeps the CRV back
        _callActions(actions);

        uint amountReceived = token.balanceOf(address(this));

        // TODO: if we trade on uniwap, i think this will be wrong
        // but getAmountsIn isn't working as expected
        uint fee = ((amount * 3) / 997) + 1;
        uint amountRequired = amount + fee;

        // pay back the flash loan
        token.safeTransfer(msg.sender, amountRequired);

        // keep the rest!
        // token.safeTransfer(sender, amountReceived - amountRequired);
        token.safeTransfer(msg.sender, amountReceived - amountRequired);
    }
}
