// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {Create2} from "@openzeppelin/utils/Create2.sol";

import {GasTokenBurner, IGasToken} from "contracts/GasTokenBurner.sol";

import {Diamond} from "./Diamond.sol";
import {DiamondCutter} from "./DiamondCutter.sol";
import {DiamondLoupe} from "./DiamondLoupe.sol";

// TODO: cute name like DiamondMine?
contract DiamondCreator is GasTokenBurner {
    // TODO: better to hard code this or pass as calldata?
    // address CHI = 0x0000000000004946c0e9F43F4Dee607b0eF1fA1c;

    // use CREATE2 to deploy ArgobytesOwnedVault with a salt
    // use GasToken (or compatable alternative) to save some gas fees
    // TODO: steps for using ERADICATE2
    constructor(
        address gastoken,
        bytes32 cutter_salt,
        bytes32 loupe_salt,
        bytes32 diamond_salt
    ) public payable {
        uint256 initial_gas = startFreeGasTokens(gastoken);

        // TODO: what if someone else has deployed a cutter contract that we can use?
        DiamondCutter cutter = new DiamondCutter{salt: cutter_salt}();

        // TODO: what if someone else has deployed a loupe contract that we can use?
        DiamondLoupe loupe = new DiamondLoupe{salt: loupe_salt}();

        // TODO: forward msg.value? we already do a transfer when we selfdestruct
        Diamond diamond = new Diamond{salt: diamond_salt}(
            address(cutter),
            address(loupe)
        );

        // transfer admin role from `this` to `msg.sender`
        bytes32 admin_role = diamond.DEFAULT_ADMIN_ROLE();

        diamond.grantRole(admin_role, msg.sender);
        diamond.renounceRole(admin_role, address(this));

        endFreeGasTokens(gastoken, initial_gas);

        // transfer any leftover gasToken to the diamond
        uint256 gastoken_balance = IGasToken(gastoken).balanceOf(address(this));

        // TODO: require this to succeed? that would be an expensive revert
        if (gastoken_balance > 0) {
            IGasToken(gastoken).transfer(address(diamond), gastoken_balance);
        }

        // selfdestruct for the gas refund
        // TODO: does this have to be last?
        // TODO: should we forward any ETH to msg.sender, or the diamond?
        // selfdestruct(msg.sender);
        selfdestruct(address(diamond));
    }
}
