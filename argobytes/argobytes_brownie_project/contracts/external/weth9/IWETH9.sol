// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

import {IERC20} from "contracts/external/erc20/IERC20.sol";

interface IWETH9 is IERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
