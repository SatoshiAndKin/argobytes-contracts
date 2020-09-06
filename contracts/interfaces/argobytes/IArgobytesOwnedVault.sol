// SPDX-License-Identifier: You can't license an interface
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {IArgobytesAtomicActions} from "./IArgobytesAtomicActions.sol";

// TODO: we are missing the GasTokenBuyer functions
interface IArgobytesOwnedVault {
    function adminAtomicActions(
        address gas_token,
        address payable atomic_actor,
        IArgobytesAtomicActions.Action[] calldata actions
    ) external payable returns (bytes memory);

    function adminAtomicTrades(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        IArgobytesAtomicActions.Action[] calldata actions
    ) external payable;

    function adminCall(
        address gas_token,
        address payable target,
        bytes calldata target_data,
        uint256 value
    ) external payable returns (bytes memory);

    function adminDelegateCall(
        address gas_token,
        address payable target,
        bytes calldata target_data
    ) external payable returns (bytes memory);

    function atomicArbitrage(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        IArgobytesAtomicActions.Action[] calldata actions
    ) external payable returns (uint256 primary_profit);

    function emergencyExit(
        address gas_token,
        IERC20[] calldata tokens,
        address to
    ) external payable;

    function grantRoles(bytes32 role, address[] calldata accounts) external;
}
