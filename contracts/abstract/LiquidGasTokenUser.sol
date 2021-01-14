// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.6;

import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";
import {Strings} from "@OpenZeppelin/utils/Strings.sol";

import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";

abstract contract LiquidGasTokenUser {
    using Strings for uint256;
    using SafeMath for uint256;

    ILiquidGasToken public constant lgt = ILiquidGasToken(
        0x000000000000C1CB11D5c062901F32D06248CE48
    );

    /**
     * @notice Based on the gas spent, buy and free optimal number of this contract's gas tokens.
     */
    function _buyAndFreeGasTokens(uint256 gas_token_amount)
        internal
        returns (bool)
    {
        // getEthToTokenOutputPrice reverts if optimal_tokens aren't available
        try lgt.getEthToTokenOutputPrice(gas_token_amount) returns (
            uint256 buy_cost
        ) {
            // TODO: if buy_cost is too much, return false

            // TODO: these numbers are going to change
            if (buy_cost < ((18145 * gas_token_amount) - 24000) * tx.gasprice) {
                // buying and freeing tokens is profitable
                // TODO: we used to catch a revert here, but i don't think we need that
                lgt.buyAndFree22457070633{value: buy_cost}(gas_token_amount);

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
     * @notice Free a specified number of another contract's gas tokens.
     * Set from == address(0) to use free instead of freeFrom
     */
    function _freeGasTokensFrom(uint256 gas_token_amount, address from)
        internal
        returns (bool)
    {
        if (from == address(0)) {
            // TODO: is try/catch what we need? we might just do address(lgt).call and return their success bool
            try lgt.free(gas_token_amount)  {
                return true;
            } catch Error(string memory reason) {
                // a revert was called inside lgt.freeFrom
                // and a reason string was provided.
                // we don't want to actually revert. we just want to return false
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                // This is executed in case revert() was used
                // or there was a failing assertion, division
                // by zero, etc. inside lgt.freeFrom
                // we don't want to actually revert. we just want to return false
            }
        } else {
            // TODO: option to freeFrom instead of free?
            // TODO: is try/catch what we need? we might just do address(lgt).call and return their success bool
            try lgt.freeFrom(gas_token_amount, from)  {
                return true;
            } catch Error(string memory reason) {
                // a revert was called inside lgt.freeFrom
                // and a reason string was provided.
                // we don't want to actually revert. we just want to return false
            } catch (
                bytes memory /*lowLevelData*/
            ) {
                // This is executed in case revert() was used
                // or there was a failing assertion, division
                // by zero, etc. inside lgt.freeFrom
                // we don't want to actually revert. we just want to return false
            }
        }

        return false;
    }

    // this will probably be inlined
    function freeGasTokens(uint256 amount, bool revert_on_fail) internal {
        return freeGasTokensFrom(amount, revert_on_fail, address(0));
    }

    function freeGasTokensFrom(
        uint256 amount,
        bool revert_on_fail,
        address from
    ) internal {
        if (amount == 0) {
            return;
        }

        if (_freeGasTokensFrom(amount, from)) {
            return;
        }

        // if there are LGT on the market available at a positive price, use them
        // our LGT bot will try to make sure we always have LGT to spend, so we probably won't use this often
        // but if LGT liquidity grows a lot and stays cheap, this could be useful
        // this contract needs ETH for this to work!
        if (_buyAndFreeGasTokens(amount)) {
            return;
        }

        if (revert_on_fail) {
            // TODO? revert if we can't free gas token?
            revert("LiquidGasTokenUser.freeGasTokens couldn't source lgt");
        }
    }

    // TODO: return success boolean? revert? or maybe return the number of gas tokens that were freed
    // in most cases, this shouldn't ever revert. we care more about the rest of the transaction succeeding than this succeeding
    function freeOptimalGasTokensFrom(
        uint256 initial_gas,
        bool revert_on_fail,
        address from
    ) internal {
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
        // keep the number of calculations after this as low as possible
        uint256 optimal_tokens = (initial_gas - gasleft() + 55000) / 41300;

        if (optimal_tokens == 0) {
            return;
        }

        // TODO: how much of a refund will we get for freeing?
        // TODO: how much ETH would we get if we simply sell these tokens

        // if there are tokens available, we can assume they were bought at a low gas price
        // if we have gas_token set, then we can assume we are at a high gas price
        // (the caller should set gas_token to 0x0 when gas prices are low)
        if (_freeGasTokensFrom(optimal_tokens, from)) {
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
            revert(
                "LiquidGasTokenUser.freeOptimalGasTokens couldn't source lgt"
            );
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
