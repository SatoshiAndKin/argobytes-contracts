// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.10;

import {SafeMath} from "@openzeppelin/math/SafeMath.sol";

import {ILGT} from "contracts/interfaces/liquidgastoken/ILGT.sol";
import {
    IGasTokenBurner
} from "contracts/interfaces/argobytes/IGasTokenBurner.sol";

contract LiquidGasTokenBurner is IGasTokenBurner {
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
        if (address(gas_token) == address(0)) {
            initial_gas = 0;
        } else {
            // TODO: add some to this? or maybe we should do that inside freeGasTokens
            initial_gas = gasleft();
        }
    }

    function freeGasTokens(address gas_token, uint256 initial_gas) internal {
        if (initial_gas > 0) {
            _buyAndFreeGasTokens(gas_token, initial_gas);
            // TODO: optional fallback to freeing our own?
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

        if (optimal_tokens > 0) {
            uint256 buy_cost = ILGT(gas_token).getEthToTokenOutputPrice(
                optimal_tokens
            );

            // TODO: these numbers are going to change
            if (buy_cost < ((18145 * optimal_tokens) - 24000) * tx.gasprice) {
                // buying and freeing tokens is profitable
                // TODO: try/except on this? we don't want reverting on gas token to be the reason we don't get an arbitrage trade
                // TODO: but what if the arb trade would only be possible if we have the gas token refund?
                try
                    ILGT(gas_token).buyAndFree22457070633{value: buy_cost}(
                        optimal_tokens
                    )
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
                    // by zero, etc. inside atomicTrade.
                }
            } else {
                // the ETH cost of buying the tokens outweighs the refund we will get from freeing them
            }

            return false;
        }
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

        if (optimal_tokens > 0) {
            if (ILGT(gas_token).free(optimal_tokens)) {
                // we freed the tokens
                return true;
            } else {
                // we didn't free the tokens. probably because we don't have enough
                // this will hopefully be the less common path

                // TODO: buy enough to have optimal_tokens?

                uint256 available_tokens = ILGT(gas_token).balanceOf(
                    address(this)
                );

                // TODO: require to check that free returned a bool?
                // TODO: check the return on this?
                return ILGT(gas_token).free(available_tokens);
            }
        }
    }

    /**
     * @notice Mint `amount` gas tokens for this contract.
     * TODO: is this safe? what if someone passes a malicious address here?
     */
    function mintGasToken(address gas_token, uint256 amount) public override {
        ILGT(gas_token).mint(amount);
    }
}
