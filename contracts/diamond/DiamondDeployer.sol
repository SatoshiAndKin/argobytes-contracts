// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {Diamond} from "./Diamond.sol";

// TODO: cute name like DiamondMine? Carbon?
contract DiamondDeployer {
    // use CREATE2 to deploy ArgobytesOwnedVault with a salt
    // TODO: steps for using ERADICATE2
    constructor(
        bytes32 diamond_salt,
        bytes32 cutter_salt,
        bytes32 loupe_salt
    ) public payable {
        Diamond deployed = new Diamond{salt: diamond_salt, value: msg.value}(
            msg.sender,
            cutter_salt,
            loupe_salt
        );

        // cut functions

        // transfer admin role

        // selfdestruct for the gas refund
        selfdestruct(address(deployed));
    }
}
