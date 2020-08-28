// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;

import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";

contract LiquidGasTokenUser {
    using Strings for uint256;
    using SafeMath for uint256;

    modifier freeGasTokensModifier(address gas_token) {
        // save our starting gas so we can burn the proper amount of gas token at the end
        uint256 initial_gas = initialGas(gas_token);

        _;

        freeGasTokens(gas_token, initial_gas);
    }

    function initialGas(address gas_token)
        internal
        view
        returns (uint256 initial_gas)
    {
        if (gas_token == address(0)) {
            initial_gas = 0;
        } else {
            // TODO: add some to this? or maybe we should do that inside freeGasTokens
            // TODO: do a test and look at the actual trace to know how much to add
            initial_gas = gasleft();
        }
    }

    // TODO: return success boolean? revert?
    function freeGasTokens(address gas_token, uint256 initial_gas) internal {
        if (initial_gas == 0) {
            return;
        }
        // if initial_gas is set, we can assume gas_token is set

        // TODO: paramater for choosing between _freeGasTokens, _buyAndFreeGasTokens, or _buyAndFreeGasTokens||_freeGasTokens
        // TODO: i don't think we want to use buyAndFree from the vault
        // the vault is going to be doing very high gas cost arbitrage trades
        // and we are going to have our own bot that is minting/buying gas token whenever it is cheap
        // the bot can also mint/sell into the liquidity pool

        if (_freeGasTokens(gas_token, initial_gas)) {
            return;
        }

        // if (_buyAndFreeGasTokens(gas_token, initial_gas)) {
        //     return;
        // }

        // TODO: we probably don't actually want to revert. but this makes debugging simpler. delete
        // revert("LiquidGasTokenUser.freeGasTokens: DEBUGGING");
    }

    /**
     * @notice Based on the gas spent, buy and free optimal number of this contract's gas tokens.
     */
    function _buyAndFreeGasTokens(address gas_token, uint256 initial_gas)
        internal
        returns (bool)
    {
        // TODO: these numbers are going to change
        // i don't think overflow checks are necessary here
        uint256 optimal_tokens = (initial_gas - gasleft() + 55000) / 41300;

        // TODO: GST2 code checked that we had enough gas to even try burning. do we need that here, too?

        if (optimal_tokens == 0) {
            return true;
        }

        // getEthToTokenOutputPrice reverts if optimal_tokens aren't available
        try
            ILiquidGasToken(gas_token).getEthToTokenOutputPrice(optimal_tokens)
        returns (uint256 buy_cost) {
            // TODO: these numbers are going to change
            if (buy_cost < ((18145 * optimal_tokens) - 24000) * tx.gasprice) {
                // buying and freeing tokens is profitable
                try
                    ILiquidGasToken(gas_token).buyAndFree22457070633{
                        value: buy_cost
                    }(optimal_tokens)
                 {
                    // gas token was bought and freed
                    // TODO: I think if we sent the wrong value, this would actually not have freed anything. but we did the check in this transaction so should be safe
                    return true;
                } catch Error(string memory reason) {
                    // a revert was called inside buyAndFree22457070633
                    // and a reason string was provided.
                } catch (
                    bytes memory /*lowLevelData*/
                ) {
                    // This is executed in case revert() was used
                    // or there was a failing assertion, division
                    // by zero, etc. inside buyAndFree22457070633.
                }
            }
        } catch Error(string memory reason) {
            // a revert was called inside getEthToTokenOutputPrice
            // and a reason string was provided.
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside getEthToTokenOutputPrice.
        }

        return false;
    }

    /**
     * @notice Based on the gas spent, free optimal number of this contract's gas tokens.
     */
    function _freeGasTokens(address gas_token, uint256 initial_gas)
        internal
        returns (bool)
    {
        // TODO: these numbers are going to change
        // i don't think overflow checks are necessary here
        uint256 optimal_tokens = (initial_gas - gasleft() + 55000) / 41300;

        // TODO: GST2 code checked that we had enough gas to even try burning. do we need that here, too?

        if (optimal_tokens == 0) {
            return true;
        }

        // we can assume that any tokens we have were acuired at a "cheap" gas cost
        uint256 available_tokens = ILiquidGasToken(gas_token).balanceOf(
            address(this)
        );

        if (available_tokens == 0) {
            return false;
        }

        if (available_tokens < optimal_tokens) {
            // TODO: buy enough to have optimal_tokens?
            // we will have our own bot minting at low gas prices and sending it here for extremely high gas cost arbitrage trades

            return ILiquidGasToken(gas_token).free(available_tokens);
        } else {
            return ILiquidGasToken(gas_token).free(optimal_tokens);
        }
    }
}
