// SPDX-License-Identifier: LGPL-3.0-or-later
// Store profits and provide them for flash lending
// Burns GasToken (or compatible contracts)
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {AccessControl} from "@OpenZeppelin/access/AccessControl.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";
import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";
import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {
    DiamondStorageContract
} from "contracts/diamond/DiamondStorageContract.sol";
import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";
import {Strings2} from "contracts/Strings2.sol";
import {
    IArgobytesAtomicActions
} from "contracts/interfaces/argobytes/IArgobytesAtomicActions.sol";
import {
    IArgobytesOwnedVault
} from "contracts/interfaces/argobytes/IArgobytesOwnedVault.sol";

// we do NOT give this contract a `receive` function since it should only be used through a diamond
contract ArgobytesOwnedVault is
    DiamondStorageContract,
    LiquidGasTokenUser,
    IArgobytesOwnedVault
{
    using SafeMath for uint256;
    using Strings for uint256;
    using Strings2 for address;
    using UniversalERC20 for IERC20;

    address internal constant ADDRESS_ZERO = address(0);

    bytes32 public constant TRUSTED_ARBITRAGER_ROLE = keccak256(
        "TRUSTED_ARBITRAGER_ROLE"
    );

    function atomicArbitrage(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20. include any tokens that might need to be swept back
        uint256 first_amount,
        bytes calldata encoded_actions
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
                encoded_actions
            )
         {
            // the trades worked!
        } catch Error(string memory reason) {
            // a revert was called inside atomicTrades
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
            // by zero, etc. inside atomicTrades.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault.atomicArbitrage -> IArgobytesAtomicActions.atomicTrades reverted without a reason"
            );
        }

        // don't trust IArgobytesAtomicActions.atomicTrades's return. Check the balance ourselves
        uint256 ending_vault_balance = borrow_token.universalBalanceOf(
            address(this)
        );

        // TODO: think about this more
        // we allow this to be equal because it's possible that we got our profits somewhere else (like from flash loan or exchange LP fees)
        if (ending_vault_balance < starting_vault_balance) {
            // uint256 decreased_amount = starting_vault_balance -
            //     ending_vault_balance;

            // // TODO: this error message costs too much gas. use it for debugging, but get rid of it in production
            // string memory err = string(
            //     abi.encodePacked(
            //         "ArgobytesOwnedVault.atomicArbitrage: Vault balance of ",
            //         address(borrow_token).toString(),
            //         " decreased by ",
            //         decreased_amount.toString()
            //     )
            // );

            // we burn gas token before the very end. that way if we revert, we get more of our gas back and don't actually burn any tokens
            // TODO: is this true? it probably shouldn't be. if not, just use the modifier. i think this also means we can free slightly more tokens
            freeGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault.atomicArbitrage: Vault balance did not increase"
            );
        }

        // TODO: return the profit in all tokens so a caller can decide if the trade is worthwhile?
        // TODO: can the caller get that now? Is that data available inside eth_call's return?
        // we do not need checked subtraction here because we check for `ending_vault_balance < starting_vault_balance` above
        primary_profit = ending_vault_balance - starting_vault_balance;

        // we made it to the end. burn some gas tokens
        // if (gas_token != ADDRESS_ZERO) {
        // keep any calculations done after this to a minimum
        // TODO: it would be nice to return how many gas tokens we burned (or their value)
        freeGasTokens(gas_token, initial_gas);

        // if our primary_profit was in ETH and we buyAndFree gas tokens, we need to adjust primary_profit!
        // TODO: is it worth the gas?
        // if (address(borrow_token) == ADDRESS_ZERO) {
        //     ending_vault_balance = address(this).balance;

        //     if (ending_vault_balance < starting_vault_balance) {
        //         // its too late too revert to actually save money
        //         // revert(
        //         //     "ArgobytesOwnedVault.atomicArbitrage: freeGasTokens made this trade no longer profitable"
        //         // );
        //         // TODO: emit a log that we just lost money
        //         primary_profit = 0;
        //     } else {
        //         primary_profit =
        //             ending_vault_balance -
        //             starting_vault_balance;
        //     }
        // }
        // }
    }

    function atomicTrades(
        address gas_token,
        address payable atomic_actor,
        address kollateral_invoker,
        address[] calldata tokens, // ETH (address(0)) or ERC20. include any tokens that might need to be swept back
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external override payable {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! anyone would be able to steal our tokens without it!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.atomicTrades: Caller is not an admin"
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
                encoded_actions
            )
         {
            // the trades worked!
        } catch Error(string memory reason) {
            // a revert was called inside atomicTrades
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
            // by zero, etc. inside atomicTrades.

            // burn our gas token before raising the same revert
            // TODO: confirm that this actually saves us gas!
            freeGasTokens(gas_token, initial_gas);

            revert(
                "ArgobytesOwnedVault.atomicArbitrage -> IArgobytesAtomicActions.atomicTrades reverted without a reason"
            );
        }

        freeGasTokens(gas_token, initial_gas);
    }

    function delegateAtomicActions(
        address gas_token,
        address atomic_actor,
        bytes calldata encoded_actions
    ) external override payable returns (bytes memory) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! this contract can do pretty much anything!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.delegateAtomicActions: Caller is not an admin"
        );

        // delgatecall is dangerous! be careful!
        (bool success, bytes memory returndata) = atomic_actor.delegatecall(
            abi.encodeWithSelector(
                IArgobytesAtomicActions.atomicActions.selector,
                encoded_actions
            )
        );

        freeGasTokens(gas_token, initial_gas);

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
            revert(
                "ArgobytesOwnedVault.delegateAtomicActions: delegatecall of IArgobytesAtomicActions"
            );
        }
    }

    function delegateCall(
        address gas_token,
        address payable target,
        bytes calldata target_data
    ) external override payable returns (bytes memory) {
        // use address(0) for gas_token to skip gas token burning
        uint256 initial_gas = initialGas(gas_token);

        // this role check is very important! this contract can do pretty much anything!
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.delegateCall: Caller is not an admin"
        );

        // delgatecall is dangerous! be careful!
        (bool success, bytes memory returndata) = target.delegatecall(
            target_data
        );

        freeGasTokens(gas_token, initial_gas);

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
            revert(
                "ArgobytesOwnedVault.delegateAtomicActions: delegatecall of IArgobytesAtomicActions"
            );
        }
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
