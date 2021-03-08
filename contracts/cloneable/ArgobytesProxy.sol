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
 *
 * TODO: think more about this. it doesn't play nice with flash loans
 * 
 */
pragma solidity 0.7.6;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {IArgobytesAuthorizationRegistry} from "contracts/ArgobytesAuthorizationRegistry.sol";
import {IArgobytesFactory} from "contracts/ArgobytesFactory.sol";
import {ArgobytesClone} from "contracts/abstract/ArgobytesClone.sol";
import {Address2} from "contracts/library/Address2.sol";
import {Bytes2} from "contracts/library/Bytes2.sol";

// it is super important that all these functions have strong authentication!
interface IArgobytesProxy {
    // delegatecall any function
    function execute(address target, bytes memory target_calldata)
        external
        payable
        returns (bytes memory response);

    // deploy a contract (if not already deployed), delegatecall a function on that contract
    function createContractAndExecute(
        IArgobytesFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    ) external payable returns (address target, bytes memory response);
}

// TODO: move this onto contracts/abstract/ArgobytesClone.sol
contract ArgobytesProxy is ArgobytesClone, IArgobytesProxy {
    using Address for address;
    using Address2 for address;
    using Bytes2 for bytes;

    /*
    Instead of deploying this contract, most users should setup a proxy to this contract that uses delegatecall

    If you do want to use this contract directly, you need to be sure to append the owner's address to the end of the bytecode!
    */
    constructor() {}

    /*
     * we shouldn't store ETH here outside a transaction,
     * but we do want to be able to receive it in one call and return in another
     */
    receive() external payable {}

    function execute(address target, bytes memory target_calldata)
        public
        override
        payable
        returns (bytes memory response)
    {
        requireAuth(target, target_calldata.toBytes4());

        require(
            Address.isContract(target),
            "ArgobytesProxy.execute BAD_TARGET"
        );

        // uncheckedDelegateCall is safe because we just checked that `target` is a contract
        response = target.uncheckedDelegateCall(
            target_calldata,
            "ArgobytesProxy.execute failed"
        );
    }

    function createContractAndExecute(
        IArgobytesFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    ) public override payable returns (address target, bytes memory response) {
        // most cases will probably want an empty salt and a self-destructing target_code
        // adding a salt adds to the calldata. that negates some of the savings from 0 bytes in target
        target = factory.checkedCreateContract(target_salt, target_code);

        requireAuth(target, target_calldata.toBytes4());

        // uncheckedDelegateCall is safe because we just used `existingOrCreate2`
        response = target.uncheckedDelegateCall(
            target_calldata,
            "ArgobytesProxy.createContractAndExecute failed"
        );
    }

    // TODO: function implementation that returns the target contract?
    // TODO: EIP-165? EIP-721 receiver?
    // TODO: gasless transactions?
}
