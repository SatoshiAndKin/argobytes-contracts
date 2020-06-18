// SPDX-License-Identifier: You can't license an interface
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

// TODO: we are missing the GasTokenBurner functions
interface IArgobytesOwnedVault {
    event Deploy(address deployed);

    /**
     * @notice Deploy the contract.
     * This is payable so that the initial deployment can fund
     */
    function trustArbitragers(
        address gastoken,
        address[] memory trusted_arbitragers
    ) external payable;

    function atomicArbitrage(
        address gastoken,
        address payable atomic_trader,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external returns (uint256 primary_profit);

    function withdrawTo(
        IERC20 token,
        address to,
        uint256 amount
    ) external returns (bool);

    function withdrawToFreeGas(
        address gastoken,
        IERC20 token,
        address to,
        uint256 amount
    ) external returns (bool);
}
