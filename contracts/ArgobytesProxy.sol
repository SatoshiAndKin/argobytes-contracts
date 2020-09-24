// SPDX-License-Identifier: LGPL-3.0-or-later

/* ArgobytesProxy
 *
 * User deploys a proxy with the ProxyFactory
 * User executes 
 *
 */
pragma solidity 0.7.0;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";
import {IERC165} from "@OpenZeppelin/introspection/IERC165.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";
import {IArgobytesProxyFactory} from "contracts/ArgobytesProxyFactory.sol";
import {ArgobytesAuth} from "contracts/ArgobytesAuth.sol";
import {Address2} from "contracts/library/Address2.sol";
import {Bytes2} from "contracts/library/Bytes2.sol";
import {Ownable2} from "contracts/Ownable2.sol";


interface IArgobytesProxy {
    function execute(bool free_gas_tokens, IArgobytesProxyFactory factory, bytes memory target_code, bytes memory target_calldata)
        external
        payable
        returns (address target, bytes memory response);
    
    function execute(bool free_gas_tokens, address target, bytes memory target_calldata)
        external
        payable
        returns (bytes memory response);
}


contract ArgobytesProxy is ArgobytesAuth, IArgobytesProxy, IERC165, LiquidGasTokenUser {
    using Address for address;
    using Address2 for address;
    using Bytes2 for bytes;

    constructor(address owner) ArgobytesAuth(owner) {}

    // do we really need this? im trying to fill a similar hole as dsproxy filled.
    // i think its useful for one-off transactions.
    // TODO: re-entrancy protection?
    function execute(bool free_gas_tokens, IArgobytesProxyFactory factory, bytes memory target_code, bytes memory target_calldata)
        public
        override
        payable
        returns (address target, bytes memory response)
    {
        uint256 initial_gas = initialGas(free_gas_tokens);

        // TODO: i think we want an empty salt. maybe take it as an argument though
        // adding a salt adds to the calldata which negates the address savings
        target = Create2.computeAddress("", keccak256(target_code), address(factory));

        // instead of authenticating the execute call, check auth for the sig (first 4 bytes) of target_calldata
        requireAuth(target, target_calldata.toBytes4());

        if (!Address2.isContract(target)) {
            // target doesn't exist. create it
            // if you want to burn gas token, do it during target_calldata
            // TODO: think more about gas token
            require(factory.deploy2(0, "", target_code, "") == target, "address mismatch");
        }

        // TODO: openzepplin's extra checks are unnecessary since we just deployed, but gas golf this later
        response = target.functionDelegateCall(target_calldata, "ArgobytesProxy: execute code reverted");

        // TODO: free gas tokens even if we revert?
        freeOptimalGasTokens(initial_gas);
    }

    function execute(bool free_gas_tokens, address target, bytes memory target_calldata)
        public
        override
        payable
        returns (bytes memory response)
    {
        uint256 initial_gas = initialGas(free_gas_tokens);

        // instead of authenticating the execute call, check auth target_calldata (first 4 bytes is the function's sig)
        requireAuth(target, target_calldata.toBytes4());

        response = target.functionDelegateCall(target_calldata, "ArgobytesProxy: execute target reverted");

        // TODO: free gas tokens even if we revert?
        freeOptimalGasTokens(initial_gas);
    }

    function supportsInterface(bytes4 interfaceId) external override view returns (bool) {
        if (interfaceId == type(IArgobytesProxy).interfaceId) {
            return true;
        }
        if (interfaceId == type(IERC165).interfaceId) {
            return true;
        }
        return false;
    }
}
