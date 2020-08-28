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

// TODO: cute name like DiamondMine?
contract DiamondCreator is LiquidGasTokenUser {
    // since this is a one-time use, self destructing contract and gas prices have been high for a while now...
    // we can hard code this instead of using a constructor param
    address constant LGT = 0x000000000000C1CB11D5c062901F32D06248CE48;

    // use CREATE2 to deploy a diamond with an efficient address
    // use LiquidGasToken to save some gas fees
    constructor(
        // address gas_token,
        bytes32 cutter_salt,
        bytes32 loupe_salt,
        bytes32 diamond_salt
    ) public payable {
        uint256 initial_gas = initialGas(LGT);

        // TODO: have an alternative DiamondCreator contract that uses pre-deployed addresses for cutter/loupe
        DiamondCutter cutter = new DiamondCutter{salt: cutter_salt}();
        DiamondLoupe loupe = new DiamondLoupe{salt: loupe_salt}();

        // any ETH left in this Creator contract will be forwarded to the diamond via selfdestruct
        Diamond diamond = new Diamond{salt: diamond_salt}(
            address(cutter),
            address(loupe)
        );

        // transfer admin role from `this` to `msg.sender`
        bytes32 admin_role = diamond.DEFAULT_ADMIN_ROLE();

        diamond.grantRole(admin_role, msg.sender);
        // TODO: since we selfdestruct, do we really need renounceRole? safest to do it
        diamond.renounceRole(admin_role, address(this));

        if (initial_gas > 0) {
            // TODO: since we are going to self destruct and get 200k back, we need to tweak how much we free. think about this more
            freeGasTokens(LGT, initial_gas + 420000);

            // transfer any remaining gas tokens
            uint256 lgt_balance = ILiquidGasToken(LGT).balanceOf(address(this));

            if (lgt_balance > 0) {
                // we don't need safeTransfer because we know this returns a bool
                // i don't think it is even worth checking this return
                ILiquidGasToken(LGT).transfer(address(diamond), lgt_balance);
            }
        }

        // selfdestruct for the gas refund (~200k gas)
        // this forwards any ETH in this contract to the diamond
        // this must be last!
        selfdestruct(address(diamond));
    }
}
