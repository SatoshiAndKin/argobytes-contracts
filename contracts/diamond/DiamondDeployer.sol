// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {Diamond} from "./Diamond.sol";
import {IDiamondCutter} from "./DiamondHeaders.sol";

// TODO: cute name like DiamondMine? Carbon?
contract DiamondDeployer {
    // use CREATE2 to deploy ArgobytesOwnedVault with a salt
    // TODO: steps for using ERADICATE2
    constructor(
        bytes32 diamond_salt,
        bytes32 cutter_salt,
        bytes32 loupe_salt,
        bytes[] memory diamond_cuts
    ) public payable {
        Diamond diamond = new Diamond{salt: diamond_salt, value: msg.value}(
            cutter_salt,
            loupe_salt
        );

        // add functions
        bytes memory cut_data = abi.encodeWithSelector(
            IDiamondCutter.diamondCut.selector,
            diamond_cuts
        );
        (bool success, ) = address(diamond).call(cut_data);
        require(success, "Adding functions failed.");

        // transfer admin role from `this` to `msg.sender`
        bytes32 admin_role = diamond.DEFAULT_ADMIN_ROLE();

        diamond.grantRole(admin_role, msg.sender);
        diamond.renounceRole(admin_role, address(this));

        // selfdestruct for the gas refund
        selfdestruct(address(diamond));
    }
}
