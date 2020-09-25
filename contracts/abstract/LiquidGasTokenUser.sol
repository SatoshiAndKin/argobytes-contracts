// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;

import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";

abstract contract LiquidGasTokenUser {
    using Strings for uint256;
    using SafeMath for uint256;

    ILiquidGasToken public constant lgt = ILiquidGasToken(0x000000000000C1CB11D5c062901F32D06248CE48);

    /**
     * @notice Based on the gas spent, buy and free optimal number of this contract's gas tokens.
     */
    function _buyAndFreeGasTokens(uint256 gas_token_amount)
        internal
        returns (bool)
    {
        // getEthToTokenOutputPrice reverts if optimal_tokens aren't available
        try
            lgt.getEthToTokenOutputPrice(gas_token_amount)
        returns (uint256 buy_cost) {
            // TODO: these numbers are going to change
            if (buy_cost < ((18145 * gas_token_amount) - 24000) * tx.gasprice) {
                // buying and freeing tokens is profitable
                // TODO: we used to catch a revert here, but i don't think we need that
                lgt.buyAndFree22457070633{
                    value: buy_cost
                }(gas_token_amount);

                return true;
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
    function _freeGasTokens(uint256 gas_token_amount)
        internal
        returns (bool)
    {
        // we can assume that any tokens we have were acuired at a "cheap" gas cost
        uint256 allowed_tokens = lgt.allowance(
            msg.sender,
            address(this)
        );
        uint256 available_tokens = lgt.balanceOf(
            msg.sender
        );

        // TODO: free some tokens if we have them
        if (allowed_tokens < available_tokens) {
            available_tokens = allowed_tokens;
        }

        if (available_tokens < gas_token_amount) {
            // we don't have enough tokens. free what we can
            lgt.freeFrom(available_tokens, msg.sender);

            // return false so that we can try another way
            return false;
        }

        // free msg.sender's tokens
        return lgt.freeFrom(available_tokens, msg.sender);
    }

    function freeGasTokens(uint256 amount, bool revert_on_fail) internal {
        if (amount == 0) {
            return;
        }

        if (_freeGasTokens(amount)) {
            return;
        }

        // if there are LGT on the market available at a positive price, use them
        // our LGT bot will try to make sure we always have LGT to spend, so we probably won't use this often
        // but if LGT liquidity grows a lot and stays cheap, this could be useful
        if (_buyAndFreeGasTokens(amount)) {
            return;
        }

        if (revert_on_fail) {
            // TODO? revert if we can't free gas token?
            revert("LiquidGasTokenUser.freeGasTokens couldn't source lgt");
        }
    }

    // TODO: return success boolean? revert?
    // this shouldn't ever revert. we care more about the rest of the transaction succeeding than this succeeding
    function freeOptimalGasTokens(uint256 initial_gas, bool revert_on_fail) internal {
        if (initial_gas == 0) {
            return;
        }
        // if initial_gas is set, we can assume we should free gas tokens

        // TODO: think about this more

        // TODO: paramater for choosing between _freeGasTokens, _buyAndFreeGasTokens, or _buyAndFreeGasTokens||_freeGasTokens
        // TODO: arguments can be made for every configuration. i'm not sure what is best
        // the ArgobytesTrader is going to be doing very high gas cost arbitrage trades
        // and we are going to have our own bot that is minting/buying gas token whenever it is cheap
        // the bot can also mint/sell into the liquidity pool

        // TODO: these numbers are going to change
        // i don't think overflow checks are necessary here
        // keep the nnumber of calculatiosn after this as low as possible
        uint256 optimal_tokens = (initial_gas - gasleft() + 55000) / 41300;

        if (optimal_tokens == 0) {
            return;
        }

        // TODO: how much of a refund will we get for freeing?
        // TODO: how much ETH would we get if we simply sell these tokens

        // if there are tokens available, we can assume they were bought at a low gas price
        // if we have gas_token set, then we can assume we are at a high gas price
        // (the caller should set gas_token to 0x0 when gas prices are low)
        if (_freeGasTokens(optimal_tokens)) {
            return;
        }

        // recalculate optimal_tokens since we might have done some calls above
        // TODO: just increment optimal_tokens by a known amount?
        // TODO: gas golf this
        optimal_tokens = (initial_gas - gasleft() + 55000) / 41300;

        // if there are LGT on the market available at a positive price, use them
        // our LGT bot will try to make sure we always have LGT to spend, so we probably won't use this often
        // but if LGT liquidity grows a lot and stays cheap, this could be useful
        if (_buyAndFreeGasTokens(optimal_tokens)) {
            return;
        }

        if (revert_on_fail) {
            revert("LiquidGasTokenUser.freeOptimalGasTokens couldn't source lgt");
        }
    }

    function initialGas(bool free_gas_token)
        internal
        view
        returns (uint256 initial_gas)
    {
        if (free_gas_token) {
            // TODO: add some to this?
            initial_gas = gasleft();
        } else {
            initial_gas = 0;
        }
    }
}
