// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {AccessControl} from "@OpenZeppelin/access/AccessControl.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";
import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";
import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {
    DiamondStorageContract
} from "contracts/diamond/DiamondStorageContract.sol";
import {LiquidGasTokenBuyer} from "contracts/LiquidGasTokenBuyer.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";
import {
    IArgobytesAtomicTrade
} from "contracts/interfaces/argobytes/IArgobytesAtomicTrade.sol";
import {
    IArgobytesOwnedVault
} from "contracts/interfaces/argobytes/IArgobytesOwnedVault.sol";

contract ArgobytesOwnedVault is
    DiamondStorageContract,
    LiquidGasTokenBuyer,
    IArgobytesOwnedVault
{
    using SafeMath for uint256;
    using Strings for uint256;
    using Strings2 for address;
    using UniversalERC20 for IERC20;

    address internal constant ADDRESS_ZERO = address(0);
    bytes32 internal constant TRUSTED_ARBITRAGER_ROLE = keccak256(
        "TRUSTED_ARBITRAGER_ROLE"
    );

    /**
     * @notice Deploy the contract.
     */
    constructor(address[] memory trusted_arbitragers) public payable {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant some addresses the "trusted arbitrager" role
        // they will be able to call "atomicArbitrage" (WITH OUR FUNDS!)
        for (uint256 i = 0; i < trusted_arbitragers.length; i++) {
            _setupRole(TRUSTED_ARBITRAGER_ROLE, trusted_arbitragers[i]);
        }
    }

    // this contract must be able to receive ether if it is expected to trade it
    receive() external payable {}

    function atomicArbitrage(
        address gas_token,
        address payable atomic_trader,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external override payable returns (uint256 primary_profit) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        require(
            hasRole(TRUSTED_ARBITRAGER_ROLE, msg.sender),
            "ArgobytesOwnedVault.atomicArbitrage: Caller is not a trusted arbitrager"
        );

        // TODO: debug_require? we only have these for helpful revert messages
        require(
            tokens.length > 0,
            "ArgobytesOwnedVault.atomicArbitrage: tokens.length must be > 0"
        );
        require(
            first_amount > 0,
            "ArgobytesOwnedVault.atomicArbitrage: first_amount must be > 0"
        );

        IERC20 borrow_token = IERC20(tokens[0]);

        uint256 starting_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // transfer tokens if we have them
        // if we don't have sufficient tokens, the next contract will borrow from kollateral or some other provider
        if (first_amount <= starting_vault_balance) {
            borrow_token.universalTransfer(atomic_trader, first_amount);

            // clear the kollateral invoker since we won't need it
            kollateral_invoker = ADDRESS_ZERO;
        } else if (starting_vault_balance > 0) {
            require(
                kollateral_invoker != ADDRESS_ZERO,
                "ArgobytesOwnedVault.atomicArbitrage: not enough funds. need kollateral_invoker"
            );

            borrow_token.universalTransfer(
                atomic_trader,
                starting_vault_balance
            );
        }
        // else we don't have any of these tokens. they will all come from kollateral or some other flash loan platform

        // notice that this is an atomic trade. it doesn't require a profitable arbitrage. we have to check that ourself after it returns
        try
            IArgobytesAtomicTrade(atomic_trader).atomicTrade(
                kollateral_invoker,
                tokens,
                first_amount,
                encoded_actions
            )
         {
            // the trade worked!
        } catch Error(string memory reason) {
            // a revert was called inside atomicTrade
            // and a reason string was provided.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeGasTokens(gas_token, initial_gas);

            revert(reason);
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside atomicTrade.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault -> IArgobytesAtomicTrade.atomicTrade reverted without a reason"
            );
        }

        // don't trust IArgobytesAtomicTrade.atomicTrade's return. It is safer to check the balance ourselves
        uint256 ending_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // we allow this to be equal because it's possible that we got our profits somewhere else (like uniswap or kollateral LP fees)
        if (ending_vault_balance < starting_vault_balance) {
            uint256 decreased_amount = starting_vault_balance -
                ending_vault_balance;
            string memory err = string(
                abi.encodePacked(
                    "ArgobytesOwnedVault.atomicArbitrage: Vault balance of ",
                    address(borrow_token).toString(),
                    " decreased by ",
                    decreased_amount.toString()
                )
            );

            // we burn gas token before the very end. that way if we revert, we get more of our gas back and don't actually burn any tokens
            // TODO: is this true? if not, just use the modifier. i think this also means we can free slightly more tokens
            freeGasTokens(gas_token, initial_gas);

            revert(err);
        }

        // TODO: return the profit in all tokens so a caller can decide if the trade is worthwhile?
        primary_profit = ending_vault_balance - starting_vault_balance;

        // we made it to the end. burn some gas tokens
        // TODO: if our primary_profit was for ETH, and we buy guy tokens here, we need to adjust primary_profit!
        freeGasTokens(gas_token, initial_gas);
    }

    function withdrawTo(
        address gas_token,
        IERC20 token,
        address to,
        uint256 amount
    )
        external
        override
        payable
        freeGasTokensModifier(gas_token)
        returns (bool)
    {
        // TODO: what role? it should be seperate from the deployer
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.withdrawTo: Caller is not an admin"
        );

        return token.universalTransfer(to, amount);
    }
}
