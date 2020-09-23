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
    // this shouldn't ever revert. we care more about the rest of the transaction succeeding than this succeeding
    function freeGasTokens(address gas_token, uint256 initial_gas) internal {
        if (initial_gas == 0) {
            return;
        }
        // if initial_gas is set, we can assume gas_token is set

        // TODO: paramater for choosing between _freeGasTokens, _buyAndFreeGasTokens, or _buyAndFreeGasTokens||_freeGasTokens
        // TODO: arguments can be made for every configuration. i'm not sure what is best
        // the vault is going to be doing very high gas cost arbitrage trades
        // and we are going to have our own bot that is minting/buying gas token whenever it is cheap
        // the bot can also mint/sell into the liquidity pool

        // if there are tokens available, we can assume they were bought at a low gas price
        // if we have gas_token set, then we can assume we are at a high gas price
        // (ergo, the caller should set gas_token to 0x0 when gas prices are low)
        if (_freeGasTokens(gas_token, initial_gas)) {
            return;
        }

        // if there are LGT on the market available at a positive price, use them
        // our LGT bot will try to make sure we always have LGT to spend, so we probably won't use this often
        // but if LGT liquidity grows a lot and stays cheap, this could be useful
        if (_buyAndFreeGasTokens(gas_token, initial_gas)) {
            return;
        }
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
                    // TODO: I think if we sent the wrong msg.value, this would actually not have freed anything. but we did the check in this transaction so should be safe
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

            // we don't want to actually revert. we just want to return false
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // This is executed in case revert() was used
            // or there was a failing assertion, division
            // by zero, etc. inside getEthToTokenOutputPrice.

            // we don't want to actually revert. we just want to return false
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
        uint256 available_tokens = ILiquidGasToken(gas_token).allowance(
            msg.sender,
            address(this)
        );

        if (available_tokens < optimal_tokens) {
            // TODO: buy enough to have optimal_tokens? free what we do have?
            // we will have our own bot minting at low gas prices and sending it here for extremely high gas cost arbitrage trades
            // return ILiquidGasToken(gas_token).freeFrom(available_tokens, msg.sender);
            return false;
        }

        return ILiquidGasToken(gas_token).freeFrom(optimal_tokens, msg.sender);
    }
}
