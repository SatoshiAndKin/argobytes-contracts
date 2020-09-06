// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";

import {Diamond} from "./Diamond.sol";
import {DiamondCutter} from "./DiamondCutter.sol";
import {DiamondLoupe} from "./DiamondLoupe.sol";
import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";

contract DiamondMine is LiquidGasTokenUser {

    address public default_cutter;
    address public default_loupe;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x0;

    // use CREATE2 to deploy a diamond with an efficient address
    // use LiquidGasToken to save some gas fees
    constructor(
        address admin,
        bytes32 cutter_salt,
        bytes32 loupe_salt,
        bytes32 diamond_salt
    ) payable {
        // since this is a one-time use, self destructing contract and gas prices have been high for a while now...
        // we can hard code this instead of using a constructor param
        address gas_token = 0x000000000000C1CB11D5c062901F32D06248CE48;

        uint256 initial_gas = initialGas(gas_token);

        default_cutter = address(new DiamondCutter{salt: cutter_salt}());
        default_loupe = address(new DiamondLoupe{salt: loupe_salt}());

        Diamond diamond = new Diamond{salt: diamond_salt}(
            default_cutter,
            default_loupe
        );

        diamond.grantRole(DEFAULT_ADMIN_ROLE, admin);

        diamond.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

        // forward any remaining liquid gas token to the diamond
        if (initial_gas > 0) {
            freeGasTokens(gas_token, initial_gas);

            // transfer any remaining gas tokens
            uint256 lgt_balance = ILiquidGasToken(gas_token).balanceOf(address(this));

            if (lgt_balance > 0) {
                // we don't need safeTransfer because we know this returns a bool
                // i don't think it is even worth checking this return
                ILiquidGasToken(gas_token).transfer(address(diamond), lgt_balance);
            }
        }

        // forward any remaining balance to the first diamond
        if (address(this).balance > 0) {
            (bool success, ) = address(diamond).call{value: address(this).balance}("");
        }
    }

    // anyone can create their own diamond from our deployments
    // TODO: this could be on the Diamond contract, but we'd have to be careful about forwarding balances
    function mine(
        address gas_token,
        address admin,
        address cutter,
        address loupe,
        bytes32 diamond_salt,
        bytes[] calldata diamond_cuts
    ) external payable freeGasTokensModifier(gas_token) returns (Diamond diamond) {
        diamond = new Diamond{salt: diamond_salt}(
            cutter,
            loupe
        );

        if (diamond_cuts.length > 0) {
            DiamondCutter(address(diamond)).diamondCut(diamond_cuts);
        }

        // pass the admin role on
        diamond.grantRole(DEFAULT_ADMIN_ROLE, admin);
        diamond.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

        // forward any remaining balance to the diamond
        if (address(this).balance > 0) {
            (bool success, ) = address(diamond).call{value: address(this).balance}("");
        }
    }
}
