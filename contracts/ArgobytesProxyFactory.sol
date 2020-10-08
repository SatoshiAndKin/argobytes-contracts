// SPDX-License-Identifier: LGPL-3.0-or-later
// deploy delegatecall proxies and free liquid gas tokens.
pragma solidity 0.7.1;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {ArgobytesProxy} from "./ArgobytesProxy.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";

contract ArgobytesProxyFactoryEvents {
    event NewProxy(
        address indexed first_owner,
        address indexed first_authority,
        bytes32 salt,
        address proxy
    );
}

// TODO: do we actually want `bytes memory extradata`? it could be useful, but i don't need it yet
interface IArgobytesProxyFactory {
    function deployProxyAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt
    ) external payable returns (address deployed);

    function deployProxyAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority
    ) external payable returns (address deployed);

    function deployProxyAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority,
        address first_owner
    ) external payable returns (address deployed);

    function deploy(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    function deployAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    function existingOrCreate2(bytes32 salt, bytes memory bytecode)
        external
        payable
        returns (address deployed);
}

// ArgobytesDeployer
// deploy contracts and burn gas tokens
// only set gas_token if the contract is large and gas prices are high
// LGT's deploy helper only buys (we might have our own tokens)
contract ArgobytesProxyFactory is
    ArgobytesProxyFactoryEvents,
    IArgobytesProxyFactory,
    LiquidGasTokenUser
{
    // build a proxy for msg.sender with owner-only auth
    // auth can be changed later by the owner
    function deployProxyAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt
    ) public override payable returns (address deployed) {
        deployed = deployProxyAndFree(
            gas_token_amount,
            require_gas_token,
            salt,
            IArgobytesAuthority(0),
            msg.sender
        );
    }

    // build a proxy for msg.sender with an authority set for more advanced auth
    function deployProxyAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority
    ) public override payable returns (address deployed) {
        deployed = deployProxyAndFree(
            gas_token_amount,
            require_gas_token,
            salt,
            first_authority,
            msg.sender
        );
    }

    // build a proxy for `first_owner` with an authority set for more advanced auth
    function deployProxyAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority,
        address first_owner
    ) public override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        freeGasTokens(gas_token_amount, require_gas_token);

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }

        // actually build the proxy
        deployed = address(
            new ArgobytesProxy{salt: salt}(first_owner, first_authority)
        );

        emit NewProxy(first_owner, address(first_authority), salt, deployed);
    }

    // deploy a contract with CREATE2 and then call a function on it
    function deploy(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) public override payable returns (address deployed) {
        deployed = Create2.deploy(0, salt, bytecode);

        if (extradata.length > 0) {
            // TODO: call or delegatecall?
            (bool success, ) = deployed.call(extradata);
            require(success, "extradata call reverted");
        }
    }

    // free gas tokens, deploy a contract with CREATE2, and then call a function on it
    function deployAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) public override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        freeGasTokensFrom(gas_token_amount, require_gas_token, msg.sender);

        deployed = deploy(salt, bytecode, extradata);

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }

    // deploy a contract if it doesn't already exist
    function existingOrCreate2(bytes32 salt, bytes memory bytecode)
        external
        override
        payable
        returns (address deployed)
    {
        deployed = Create2.computeAddress(salt, keccak256(bytecode));

        if (!Address.isContract(deployed)) {
            // deployed doesn't exist. create it
            require(
                Create2.deploy(0, salt, bytecode) == deployed,
                "ArgobytesProxyFactory: BAD_DEPLOY_ADDRESS"
            );
        }
    }
}
