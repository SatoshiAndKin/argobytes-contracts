// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";

import {Diamond} from "./Diamond.sol";
import {DiamondFacet} from "./facets/DiamondFacet.sol";
import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";

contract DiamondCreator is LiquidGasTokenUser {
    // since this is a one-time use, self-destructing contract and gas prices have been high for a while now...
    // we can hard code this instead of using a constructor param
    address constant gas_token = 0x000000000000C1CB11D5c062901F32D06248CE48;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // use CREATE2 to deploy a diamond with an efficient address
    // use LiquidGasToken to save some gas fees
    // self destruct to save some more gas fees
    constructor(
        bytes32 facet_salt,
        bytes32 diamond_salt
    ) payable {
        uint256 initial_gas = initialGas(gas_token);

        DiamondFacet facet = new DiamondFacet{salt: facet_salt}();

        Diamond diamond = new Diamond{salt: diamond_salt}(
            msg.sender,
            address(facet)
        );

        // forward any remaining liquid gas token to the diamond
        if (initial_gas > 0) {
            // we add to initial gas because selfdestruct has a refund (at least for now)
            freeGasTokens(gas_token, initial_gas + 400000);

            // transfer any remaining gas tokens
            uint256 lgt_balance = ILiquidGasToken(gas_token).balanceOf(address(this));

            if (lgt_balance > 0) {
                // we don't need safeTransfer because we know this returns a bool
                // i don't think it is even worth checking this return
                ILiquidGasToken(gas_token).transfer(address(diamond), lgt_balance);
            }
        }

        // forward any remaining ETH to the diamond
        selfdestruct(address(diamond));
    }
}
