// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import {IERC165} from "@OpenZeppelin/introspection/IERC165.sol";

import {IArgobytesOwnedVault} from "./IArgobytesOwnedVault.sol";
import {IAccessControl} from "../openzeppelin/IAccessControl.sol";
import {IDiamondCut} from "../../diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../diamond/interfaces/IDiamondLoupe.sol";

interface IArgobytesDiamond is
    IAccessControl,
    IArgobytesOwnedVault,
    IDiamondCut,
    IDiamondLoupe,
    IERC165
{
    // // public variable
    // TODO: this isn't available on the diamond. its on the owned vault
    // function TRUSTED_ARBITRAGER_ROLE() external view returns (bytes32);

    // public variable
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}
