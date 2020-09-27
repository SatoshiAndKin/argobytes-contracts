// SPDX-License-Identifier: LGPL-3.0-or-later

/* ArgobytesVault
 *
 * User deploys a proxy with the ProxyFactory
 * User sets up a smart contract for auth
 * User approves bot to call `ArgobytesTrader.atomicArbitrage`
 * User sends tokens/ETH to the proxy
 * Bot makes money. Bot can steal arbitrage trade profits, but not more.
 * Bot can waste our liquidgastoken
 */
pragma solidity 0.7.1;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {IArgobytesVaultFactory} from "./ArgobytesVaultFactory.sol";
import {ArgobytesAuth} from "./abstract/ArgobytesAuth.sol";
import {Address2} from "./library/Address2.sol";
import {Bytes2} from "./library/Bytes2.sol";
import {Ownable2} from "./abstract/Ownable2.sol";
import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";


// it is super important that all these functions have strong authentication!
interface IArgobytesVault {

    // delegatecall any function
    function execute(
        address target,
        bytes memory target_calldata
    )
        external
        payable
        returns (bytes memory response);

    // deploy a contract, delegatecall a function
    function deployAndExecuteAndFree(
        IArgobytesVaultFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    )
        external
        payable
        returns (address target, bytes memory response);   
}

contract ArgobytesVault is ArgobytesAuth, IArgobytesVault, LiquidGasTokenUser {
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

        response = target.functionDelegateCall(target_calldata, "ArgobytesVault.execute failed");
    }

    function executeAndFree(
        address target,
        bytes memory target_calldata
    )
        public
        override
        payable
        returns (bytes memory response)
    {
        uint256 initial_gas = initialGas(free_gas_token);

        // this does the auth
        response = execute(target, target_calldata);

        // keep calculations after this to a minimum
        // free gas tokens (this might spend some of our ETH)
        // TODO: gas golf this. we don't need to call owner() until later
        freeOptimalGasTokensFrom(initial_gas, require_gas_token, owner());
    }

    function deployAndExecuteAndFree(
        IArgobytesVaultFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    )
        public
        override
        payable
        returns (address target, bytes memory response)
    {
        uint256 initial_gas = initialGas(free_gas_token);

        // TODO: pass calldata to the _deploy function?
        // its helpful in some cases, but i thik contracts we use here will be designed with ArgobytesVaults in mind
        target = _deploy(factory, target_salt, target_code);

        // this uses delegatecall! be careful!
        response = execute(target, target_calldata);

        // keep calculations after this to a minimum
        // free gas tokens (this might spend some of our ETH)
        // TODO: gas golf this. we don't need to call owner() until later
        freeOptimalGasTokensFrom(initial_gas, require_gas_token, owner());
    }

    function _deploy(
        IArgobytesVaultFactory factory,
        bytes32 target_salt,
        bytes memory target_code
    ) internal returns (address target) {
        // TODO: i think we want an empty salt. maybe take it as an argument though
        // adding a salt adds to the calldata would negate some of savings from 0 bytes in target
        target = Create2.computeAddress(target_salt, keccak256(target_code), address(factory));

        if (!target.isContractInternal()) {
            // target doesn't exist. create it
            // if you want to burn gas token, do it during target_calldata
            // TODO: think more about gas token
            require(factory.deploy2(target_salt, target_code, "") == target, "ArgobytesVault: BAD_DEPLOY_ADDRESS");
        }
    }

}
