pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {IERC165} from "@openzeppelin/introspection/IERC165.sol";

import {IArgobytesOwnedVault} from "./IArgobytesOwnedVault.sol";
import {IGasTokenBurner} from "./IGasTokenBurner.sol";
import "contracts/diamond/DiamondHeaders.sol";

interface IArgobytesDiamond is
    IArgobytesOwnedVault,
    IDiamondCutter,
    IDiamondLoupe,
    IERC165,
    IGasTokenBurner
{}
