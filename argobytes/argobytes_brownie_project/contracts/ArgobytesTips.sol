// SPDX-License-Identifier: MPL-2.0
// don't call this contract directly! use a proxy like DSProxy or ArgobytesProxy!
// TODO: use a generic flash loan contract instead of hard coding dydx?
// TODO: consistent revert strings
pragma solidity 0.8.4;
pragma abicoder v2;

import {IENS, IResolver} from "contracts/external/ens/ENS.sol";

abstract contract ArgobytesTips {
    IENS constant ens = IENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    // we could use an immutable, but this is easier
    // `brownie.web3.ens.namehash("tip.satoshiandkin.eth")`
    bytes32 public constant TIP_NAMEHASH = 0x6797569217323c160453d50601152fd4a68e66c4c1fd0bfc8a3f902fa488d465;

    function resolve_tip_address() internal returns (address payable) {
        IResolver resolver = ens.resolver(TIP_NAMEHASH);
        return payable(resolver.addr(TIP_NAMEHASH));
    }
}
