// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.5;

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
