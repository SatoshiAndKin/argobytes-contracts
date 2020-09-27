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

    // call any function
    function call(
        address target,
        bytes memory target_calldata,
        uint256 target_value
    )
        external
        payable
        returns (bytes memory response);

    // call any function, free gas token
    function callAndFree(
        bool free_gas_token,
        bool require_gas_token,
        address target,
        bytes memory target_calldata,
        uint256 target_value
    )
        external
        payable
        returns (bytes memory response);

    // deploy a contract, call a function, free gas token
    function deployAndCallAndFree(
        bool free_gas_token,
        bool require_gas_token,
        IArgobytesVaultFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata,
        uint256 target_value
    )
        external
        payable
        returns (address target, bytes memory response);


    // delegatecall any function
    function delegateCall(
        address target,
        bytes memory target_calldata
    )
        external
        payable
        returns (bytes memory response);

    // delegatecall any function, free gas token
    function delegateCallAndFree(
        bool free_gas_token,
        bool require_gas_token,
        address target,
        bytes memory target_calldata
    )
        external
        payable
        returns (bytes memory response);

    // deploy a contract, delegatecall a function, free gas token
    function deployAndDelegateCallAndFree(
        bool free_gas_token,
        bool require_gas_token,
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

    receive() external payable {}

    function call(
        address target,
        bytes memory target_calldata,
        uint256 target_value
    )
        public
        override
        payable
        returns (bytes memory response)
    {
        requireAuth(false, target, target_calldata.toBytes4());

        response = target.functionCallWithValue(target_calldata, target_value, "ArgobytesVault.proxyCall failed");
    }

    function callAndFree(
        bool free_gas_token,
        bool require_gas_token,
        address target,
        bytes memory target_calldata,
        uint256 target_value
    )
        public
        override
        payable
        returns (bytes memory response)
    {
        uint256 initial_gas = initialGas(free_gas_token);

        // this does the auth
        response = call(target, target_calldata, target_value);

        // keep calculations after this to a minimum
        // free gas tokens (this might spend some of our ETH)
        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    function deployAndCallAndFree(
        bool free_gas_token,
        bool require_gas_token,
        IArgobytesVaultFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata,
        uint256 target_value
    )
        public
        override
        payable
        returns (address target, bytes memory response)
    {
        uint256 initial_gas = initialGas(free_gas_token);

        target = _deploy(factory, target_salt, target_code, target_calldata);

        // this does the auth
        response = call(target, target_calldata, target_value);

        // keep calculations after this to a minimum
        // free gas tokens (this might spend some of our ETH)
        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    function delegateCall(
        address target,
        bytes memory target_calldata
    )
        public
        override
        payable
        returns (bytes memory response)
    {
        requireAuth(true, target, target_calldata.toBytes4());

        response = target.functionDelegateCall(target_calldata, "ArgobytesVault.delegatecall failed");
    }

    function delegateCallAndFree(
        bool free_gas_token,
        bool require_gas_token,
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
        response = delegateCall(target, target_calldata);

        // keep calculations after this to a minimum
        // free gas tokens (this might spend some of our ETH)
        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    function deployAndDelegateCallAndFree(
        bool free_gas_token,
        bool require_gas_token,
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

        target = _deploy(factory, target_salt, target_code, target_calldata);

        response = delegateCall(target, target_calldata);

        // keep calculations after this to a minimum
        // free gas tokens (this might spend some of our ETH)
        freeOptimalGasTokens(initial_gas, require_gas_token);
    }

    function _deploy(
        IArgobytesVaultFactory factory,
        bytes32 target_salt,
        bytes memory target_code,
        bytes memory target_calldata
    ) internal returns (address target) {
        // TODO: i think we want an empty salt. maybe take it as an argument though
        // adding a salt adds to the calldata would negate some of savings from 0 bytes in target
        target = Create2.computeAddress(target_salt, keccak256(target_code), address(factory));

        if (!target.isContractInternal()) {
            // target doesn't exist. create it
            // if you want to burn gas token, do it during target_calldata
            // TODO: think more about gas token
            require(factory.deploy2(target_salt, target_code, "") == target, "ArgobytesVault: bad_address");
        }
    }

}
