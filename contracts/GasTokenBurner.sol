// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.8;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {SafeMath} from "@openzeppelin/math/SafeMath.sol";

import {IGasToken} from "interfaces/gastoken/IGasToken.sol";

contract GasTokenBurner is AccessControl {
    using SafeMath for uint256;

    IGasToken public _gas_token;
    uint8 public _gas_token_mint_amount;

    constructor(address gas_token) public {
        _gas_token = IGasToken(gas_token);
        _gas_token_mint_amount = 26;
    }

    modifier freeGasTokens {
        // save our starting gas so we can burn the proper amount of gas token at the end
        uint256 initial_gas = startFreeGasTokens();

        _;

        endFreeGasTokens(initial_gas);
    }

    function startFreeGasTokens() internal view returns (uint256 initial_gas) {
        if (address(_gas_token) == address(0x0)) {
            initial_gas = 0;
        } else {
            initial_gas = gasleft();
        }
    }

    function endFreeGasTokens(uint256 initial_gas) internal {
        if (initial_gas > 0) {
            uint gas_spent = initial_gas.sub(gasleft());
            _freeGasTokens(gas_spent);
        }
    }

    /**
     * @notice Based on the gas spent, free optimal number of this contract's gas tokens.
     */
    function _freeGasTokens(uint gas_spent) internal {
        // calculate the optimal number of tokens to free based on gas_spent
        // TODO: this is the number that 1inch uses. Not sure where they got it. They are lame about people "copying" them, so lets do more research. It's a simple function though. they can't own that
        uint num_tokens = (gas_spent + 14154) / 41130;

        // https://github.com/projectchicago/gastoken/blob/81325843c710fbcf0d77ea5a5e8323d373b09f88/contract/gst2_free_example.sol#L8
		// we need at least
		//     num_tokens * (1148 + 5722 + 150) + 25710 gas before entering destroyChildren
		//                   ^ mk_contract_address
		//                                        ^ solidity bug constant
		//                          ^ cost of invocation
		//                                 ^ loop, etc...
		// to be on the safe side, let's add another constant 2k gas
		// for CALLing freeFrom, reading from storage, etc...
		// so we get
		//     gas cost to freeFromUpTo n tokens <= 27710 + n * (1148 + 5722 + 150)

		// Note that 27710 is sufficiently large that we always have enough
		// gas left to update s_tail, balance, etc... after we are done
		// with destroyChildren.

		uint gas = gasleft();

        if (gas < 27710) {
            // there is not enough gas left to burn any gas tokens
            return;
        }

        // TODO: does solidity have a "max" helper?
		uint safe_num_tokens = (gas - 27710) / (1148 + 5722 + 150);

		if (num_tokens > safe_num_tokens) {
			num_tokens = safe_num_tokens;
		}

		if (num_tokens > 0) {
            // freeUpTo instead of free in case our gasToken balance is 0 (or even just less than we need)
            // it would suck to lose arbitrage profits becase we didn't have enough gas tokens
			_gas_token.freeUpTo(num_tokens);
		}
	}

    /**
     * @notice Mint `_gas_token_mint_amount` gas tokens for this contract.
     */
    function mintGasToken() public {
        _gas_token.mint(_gas_token_mint_amount);
    }

    function setGasToken(address gas_token) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not default admin");

        // TODO: emit an event

        _gas_token = IGasToken(gas_token);
    }

    function setGasTokenMintAmount(uint8 gas_token_mint_amount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not default admin");

        // TODO: emit an event

        _gas_token_mint_amount = gas_token_mint_amount;
    }
}