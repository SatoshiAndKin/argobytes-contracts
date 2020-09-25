// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {AccessControl} from "@OpenZeppelin/access/AccessControl.sol";
import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";
import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";
import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";
import {UniversalERC20} from "contracts/library/UniversalERC20.sol";
// import {Strings2} from "contracts/library/Strings2.sol";
import {
    IArgobytesAtomicActions,
    IArgobytesOwnedVault
} from "contracts/interfaces/argobytes/IArgobytesOwnedVault.sol";

// we do NOT give this contract a `receive` function since it should only be used through a diamond
contract ArgobytesVault is
    AccessControl,
    LiquidGasTokenUser,
    IArgobytesOwnedVault
{
    using Address for address payable;
    using SafeMath for uint256;
    using Strings for uint256;
    // using Strings2 for address;
    using UniversalERC20 for IERC20;

    address internal constant ADDRESS_ZERO = address(0);

    // the DEFAULT_ADMIN_ROLE is inherited from DiamondStorageContract
    // Trusted Arbitragers are allowed to call the atomicArbitrage function
    // They have to be trusted because they could keep all the profits for themselves
    bytes32 public constant TRUSTED_ARBITRAGER_ROLE = keccak256(
        "ArgobytesOwnedVault TRUSTED_ARBITRAGER_ROLE"
    );
    // This role is needed to receive from `exitTo`
    // while we could also withdraw with `adminAtomicActions`,
    bytes32 public constant EXIT_ROLE = keccak256(
        "ArgobytesOwnedVault EXIT_ROLE"
    );
    // This role is allowed to call `exitTo`
    // If an exploit is draining funds, this role can sweep everything
    bytes32 public constant ALARM_ROLE = keccak256(
        "ArgobytesOwnedVault ALARM_ROLE"
    );

    // admin-only frontdoor
    // useful for taking arbitrary actions. be careful with this!
    function adminAtomicActions(
        address gas_token,
        address payable atomic_actor,
        IArgobytesAtomicActions.Action[] calldata actions
    ) external override payable returns (bytes memory) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! this function can do pretty much anything!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.delegateAtomicActions: Caller is not an admin"
        );

        // delegatecall is dangerous! be careful! atomic_actor has full control of this contract's storage!
        return
            _delegateCall(
                gas_token,
                initial_gas,
                atomic_actor,
                abi.encodeWithSelector(
                    IArgobytesAtomicActions.atomicActions.selector,
                    actions
                )
            );
    }

    // admin-only frontdoor
    // useful for sending value and approving tokens
    function adminCall(
        address gas_token,
        address payable target,
        bytes calldata target_data,
        uint256 value
    ) external override payable returns (bytes memory) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! this function can do pretty much anything!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.adminCall: Caller is not an admin"
        );

        bytes memory returndata = "";

        if (target_data.length > 0) {
            returndata = target.functionCallWithValue(
                target_data,
                value,
                "ArgobytesOwnedVault.adminCall failed"
            );
        } else {
            target.sendValue(value);
        }

        // TODO: free on revert, too
        freeOptimalGasTokens(gas_token, initial_gas);

        return returndata;
    }

    function atomicArbitrage(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20. include any tokens that might need to be swept back
        uint256 first_amount,
        IArgobytesAtomicActions.Action[] calldata actions
    ) external override payable returns (uint256 primary_profit) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! coins could be stolen by this function
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
        if (first_amount <= starting_vault_balance) {
            // we won't need to invoke kollateral
            kollateral_invoker = ADDRESS_ZERO;

            borrow_token.universalTransfer(atomic_actor, first_amount);
        } else {
            // we don't have enough funds to do the trade without kollateral
            require(
                kollateral_invoker != ADDRESS_ZERO,
                "ArgobytesOwnedVault.atomicArbitrage: not enough funds. need kollateral_invoker"
            );

            if (starting_vault_balance > 0) {
                // we do have some funds though. send what we have
                borrow_token.universalTransfer(
                    atomic_actor,
                    starting_vault_balance
                );
            }
        }

        // notice that this is "atomicTrades". it doesn't require a profitable arbitrage. we have to check that after it returns
        // we ignore the atomic_actor's return because we
        // we do NOT do a delegate call here. this should be safer, but malicious contracts could probably still do sneaky things
        try
            IArgobytesAtomicActions(atomic_actor).atomicTrades(
                kollateral_invoker,
                tokens,
                first_amount,
                actions
            )
         {
            // the trades worked!
        } catch Error(string memory reason) {
            // a revert was called inside atomicTrades
            // and a reason string was provided.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeOptimalGasTokens(gas_token, initial_gas);

            revert(reason);
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside atomicTrades.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeOptimalGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault.atomicArbitrage -> IArgobytesAtomicActions.atomicTrades reverted without a reason"
            );
        }

        // don't trust IArgobytesAtomicActions.atomicTrades's return. Check the balance ourselves
        uint256 ending_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // we allow this to be equal because it's possible that we got our profits somewhere else (like from flash loan or exchange LP fees)
        if (ending_vault_balance < starting_vault_balance) {
            // TODO: this error message costs too much gas. use it for debugging, but get rid of it in production
            // uint256 decreased_amount = starting_vault_balance -
            //     ending_vault_balance;
            // string memory err = string(
            //     abi.encodePacked(
            //         "ArgobytesOwnedVault.atomicArbitrage: Vault balance of ",
            //         address(borrow_token).toString(),
            //         " decreased by ",
            //         decreased_amount.toString()
            //     )
            // );

            // we burn gas token before the very end. that way if we revert, we get more of our gas back and don't actually burn any tokens
            // TODO: is this true? it probably shouldn't be. if not, just use the modifier
            freeOptimalGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault.atomicArbitrage: Vault balance did not increase"
            );
        }

        // TODO? return the profit in all tokens so a caller can decide if the trade is worthwhile
        // we do not need safemath's `sub` here because we check for `ending_vault_balance < starting_vault_balance` above
        primary_profit = ending_vault_balance - starting_vault_balance;

        // we made it to the end! free some gas tokens
        // keep any calculations done after this to a minimum
        freeOptimalGasTokens(gas_token, initial_gas);

        // it would be nice to return how many gas tokens we burned (since it does change our profits), but we can get that offchain
    }

    function adminAtomicTrades(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20. include any tokens that might need to be swept back
        uint256 first_amount,
        IArgobytesAtomicActions.Action[] calldata actions
    ) external override payable {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! anyone would be able to steal our tokens without it!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.atomicTrades: Caller is not an admin"
        );

        // TODO: get rid of these requires in prod. they are only needed for nice error messages in dev
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
        if (first_amount <= starting_vault_balance) {
            // we won't need to invoke kollateral
            kollateral_invoker = ADDRESS_ZERO;

            borrow_token.universalTransfer(atomic_actor, first_amount);
        } else {
            // we don't have enough funds to do the trade without kollateral. but we do have some
            require(
                kollateral_invoker != ADDRESS_ZERO,
                "ArgobytesOwnedVault.atomicTrades: not enough funds. need kollateral_invoker"
            );

            if (starting_vault_balance > 0) {
                // we do have some funds though. send what we have
                borrow_token.universalTransfer(
                    atomic_actor,
                    starting_vault_balance
                );
            }
        }

        // notice that this is "atomicTrades". it doesn't require a profitable arbitrage!
        // we do NOT do a delegate call here. this should be safer, but malicious contracts could probably still do sneaky things
        try
            IArgobytesAtomicActions(atomic_actor).atomicTrades(
                kollateral_invoker,
                tokens,
                first_amount,
                actions
            )
         {
            // the trades worked!
        } catch Error(string memory reason) {
            // a revert was called inside atomicTrades
            // and a reason string was provided.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeOptimalGasTokens(gas_token, initial_gas);

            revert(reason);
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside atomicTrades.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeOptimalGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault.atomicTrades -> IArgobytesAtomicActions.atomicTrades reverted without a reason"
            );
        }

        freeOptimalGasTokens(gas_token, initial_gas);
    }

    // admin-only backdoor
    function adminDelegateCall(
        address gas_token,
        address payable target,
        bytes calldata target_data
    ) external override payable returns (bytes memory) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! this function can do pretty much anything!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.delegateCall: Caller is not an admin"
        );

        // delegatecall is dangerous! be careful! target has full control of this contract's storage!
        return
            _externalDelegateCall(gas_token, initial_gas, target, target_data);
    }

    function _delegateCall(
        address gas_token,
        uint256 initial_gas,
        address payable target,
        bytes memory target_data
    ) internal returns (bytes memory) {
        // delegatecall is dangerous! be careful!
        (bool success, bytes memory returndata) = target.delegatecall(
            target_data
        );

        freeOptimalGasTokens(gas_token, initial_gas);

        if (success) {
            return returndata;
        }

        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly

            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert("ArgobytesOwnedVault._externalDelegateCall failed");
        }
    }

    // copy-paste of _delegateCall, but with "calldata" instead of "memory" for target_data
    function _externalDelegateCall(
        address gas_token,
        uint256 initial_gas,
        address payable target,
        bytes calldata target_data
    ) internal returns (bytes memory) {
        // delegatecall is dangerous! be careful!
        (bool success, bytes memory returndata) = target.delegatecall(
            target_data
        );

        freeOptimalGasTokens(gas_token, initial_gas);

        if (success) {
            return returndata;
        }

        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly

            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert("ArgobytesOwnedVault._externalDelegateCall failed");
        }
    }

    // If an exploit is draining funds, this role can sweep everything that is left
    function emergencyExit(
        address gas_token,
        IERC20[] calldata tokens,
        address to
    ) external override payable freeGasTokensModifier(gas_token) {
        // TODO: should TRUSTED_ARBITRAGER_ROLE be allowed to call this?
        require(
            hasRole(ALARM_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                hasRole(TRUSTED_ARBITRAGER_ROLE, msg.sender),
            "ArgobytesOwnedVault.exitTo: Caller does not have the alarm or admin roles"
        );
        require(
            hasRole(EXIT_ROLE, to),
            "ArgobytesOwnedVault.exitTo: Destination is not an exit"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amount = tokens[i].universalBalanceOf(address(this));

            tokens[i].universalTransfer(to, amount);
        }
    }

    // admins can grant any role at any time
    function grantRoles(bytes32 role, address[] calldata accounts)
        external
        override
    {
        // this role check is very important!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.grantRoles: Caller is not an admin"
        );

        for (uint256 i = 0; i < accounts.length; i++) {
            _setupRole(role, accounts[i]);
        }
    }
}
