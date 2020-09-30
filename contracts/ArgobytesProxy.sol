// SPDX-License-Identifier: LGPL-3.0-or-later

/* ArgobytesProxy
 *
 * User deploys a proxy with the ProxyFactory
 * User sets up a smart contract for auth
 * User approves bot to call `ArgobytesTrader.atomicArbitrage`
 * User sends tokens/ETH to the proxy
 * Bot makes money. Bot can steal arbitrage trade profits, but not more.
 * Bot can waste our liquidgastoken

 * vault isn't very accurate. the vault doesn't hold any funds. its approved to use them instead
 */
pragma solidity 0.7.1;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {IArgobytesProxyFactory} from "./ArgobytesProxyFactory.sol";
import {ArgobytesAuth} from "./abstract/ArgobytesAuth.sol";
import {Address2} from "./library/Address2.sol";
import {Bytes2} from "./library/Bytes2.sol";
import {Ownable2} from "./abstract/Ownable2.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";


// it is super important that all these functions have strong authentication!
interface IArgobytesProxy {

    // delegatecall any function
    function execute(
        address target,
        bytes memory target_calldata
    )
        external
        payable
        returns (bytes memory response);

    // deploy a contract (if not already deployed), delegatecall a function on that contract
    function deployAndExecute(
        IArgobytesProxyFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    )
        external
        payable
        returns (address target, bytes memory response);   
}

contract ArgobytesProxy is ArgobytesAuth, IArgobytesProxy {
    using Address for address;
    using Address2 for address;
    using Bytes2 for bytes;

    constructor(address owner, IArgobytesAuthority authority) ArgobytesAuth(owner, authority) {}

    /*
    * we shouldn't store ETH here outside a transaction,
    * but we do want to be able to receive it in one call and return in another
    */
    receive() external payable {}

    function execute(
        address target,
        bytes memory target_calldata
    )
        public
        override
        payable
        returns (bytes memory response)
    {
        requireAuth(target, target_calldata.toBytes4());

        require(Address.isContract(target), "ArgobytesProxy.execute BAD_TARGET");

        // this is safe because we just checked that `target` is a contract
        response = target.uncheckedDelegateCall(target_calldata, "ArgobytesProxy.execute failed");
    }

    function deployAndExecute(
        IArgobytesProxyFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    )
        public
        override
        payable
        returns (address target, bytes memory response)
    {
        // TODO: i think we want an empty salt. maybe take it as an argument though
        // adding a salt adds to the calldata would negate some of savings from 0 bytes in target
        target = factory.existing_or_deploy2(target_salt, target_code);

        requireAuth(target, target_calldata.toBytes4());

        // this is safe because, thanks to `existing_or_deploy2`, we know `target` is a contract
        response = target.uncheckedDelegateCall(target_calldata, "ArgobytesProxy.deployAndExecute failed");
    }
}
