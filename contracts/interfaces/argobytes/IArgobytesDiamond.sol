// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {IERC165} from "@OpenZeppelin/introspection/IERC165.sol";

import {IArgobytesOwnedVault} from "./IArgobytesOwnedVault.sol";
import {
    IDiamondCutter,
    IDiamondLoupe
} from "contracts/diamond/DiamondHeaders.sol";
import {IAccessControl} from "../openzeppelin/IAccessControl.sol";

interface IArgobytesDiamond is
    IAccessControl,
    IArgobytesOwnedVault,
    IDiamondCutter,
    IDiamondLoupe,
    IERC165
{}
