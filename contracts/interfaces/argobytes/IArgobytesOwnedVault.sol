// SPDX-License-Identifier: You can't license an interface
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

// TODO: we are missing the GasTokenBuyer functions
interface IArgobytesOwnedVault {
    function atomicActions(
        address gas_token,
        address atomic_trader,
        bytes calldata encoded_actions
    ) external;

    function atomicArbitrage(
        address gas_token,
        address payable atomic_trader,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external payable returns (uint256 primary_profit);

    function withdrawTo(
        address gas_token,
        IERC20 token,
        address to,
        uint256 amount
    ) external payable returns (bool);
}
