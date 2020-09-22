// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {Create2} from "@OpenZeppelin/utils/Create2.sol";
import {Address} from "@OpenZeppelin/utils/Address.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";

import {Diamond} from "./Diamond.sol";
import {DiamondFacet} from "./facets/DiamondFacet.sol";
import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";
import "./interfaces/IDiamondCut.sol";
import "./interfaces/IDiamondLoupe.sol";

contract DiamondCloner is LiquidGasTokenUser {
    using Address for address payable;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // use CREATE2 to deploy a diamond with an efficient address
    // use LiquidGasToken to save some gas fees
    // self destruct to save some more gas fees
    function clone(
        address gas_token,
        address payable diamond_to_copy,
        bytes32 diamond_salt,
        uint256 tip
    ) external payable {
        uint256 initial_gas = initialGas(gas_token);

        // get the facet address out of the original diamond
        address facet = IDiamondLoupe(diamond_to_copy).facetAddress(IDiamondCut(diamond_to_copy).diamondCut.selector);

        // TODO: calldata for this?
        Diamond diamond = new Diamond{salt: diamond_salt}(
            msg.sender,
            facet
        );

        // TODO: cut the diamond with all the rest of the functions 
        // TODO: maybe this is dangerous. someone could frontrun a clone
        // TODO: the client could check this, but then they have a corrupted contract

        // send the tip before potentially paying for gas tokens
        if (tip > 0) {
            diamond_to_copy.sendValue(tip);
        }

        freeGasTokens(gas_token, initial_gas);
    }
}
