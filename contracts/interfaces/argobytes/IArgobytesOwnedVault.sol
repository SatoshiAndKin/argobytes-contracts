// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

interface IArgobytesOwnedVault {
    /**
     * @notice Deploy the contract.
     * This is payable so that the initial deployment can fund
     */
    function trustArbitragers(address[] memory trusted_arbitragers)
        external
        payable;

    function atomicArbitrage(
        address gastoken,
        address payable atomic_trader,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external returns (uint256 primary_profit);

    // use CREATE2 to deploy with a salt and free gas tokens
    function deploy2_and_burn(
        address gas_token,
        bytes32 salt,
        bytes memory bytecode
    ) external payable returns (address deployed);

    // use CREATE2 to deploy with a salt, cut the diamond, and free gas tokens
    function deploy2_cut_and_burn(
        address gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes[] memory diamondCuts
    ) external payable returns (address deployed);

    function withdrawTo(
        IERC20 token,
        address to,
        uint256 amount
    ) external returns (bool);

    function withdrawToFreeGas(
        address gas_token,
        IERC20 token,
        address to,
        uint256 amount
    ) external returns (bool);
}
