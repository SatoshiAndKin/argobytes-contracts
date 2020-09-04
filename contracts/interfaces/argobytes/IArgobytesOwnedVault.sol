// SPDX-License-Identifier: You can't license an interface
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

// TODO: we are missing the GasTokenBuyer functions
interface IArgobytesOwnedVault {
    function atomicArbitrage(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external payable returns (uint256 primary_profit);

    function atomicTrades(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external payable;

    function delegateAtomicActions(
        address gas_token,
        address payable atomic_actor,
        bytes calldata encoded_actions
    ) external payable returns (bytes memory);

    function delegateCall(
        address gas_token,
        address payable target,
        bytes calldata target_data
    ) external payable returns (bytes memory);

    function grantRoles(bytes32 role, address[] calldata accounts) external;

    function exitTo(
        address gas_token,
        IERC20[] calldata tokens,
        address to
    ) external payable;
}
