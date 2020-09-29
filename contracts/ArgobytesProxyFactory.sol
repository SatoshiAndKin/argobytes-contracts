// SPDX-License-Identifier: LGPL-3.0-or-later
// deploy delegatecall proxies and free liquid gas tokens.
pragma solidity 0.7.1;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {ArgobytesProxy} from "./ArgobytesProxy.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";

interface IArgobytesProxyFactory {
    event NewVault(
        address indexed sender,
        address indexed first_admin,
        address proxy
    );

    function buildVaultAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt
    ) external payable returns (address deployed);

    function buildVaultAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority
    ) external payable returns (address deployed);

    function buildVaultAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority,
        address first_owner
    ) external payable returns (address deployed);

    function deploy2(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    function deploy2AndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    function existing_or_deploy2(bytes32 salt, bytes memory bytecode)
        external
        payable
        returns (address deployed);
}

// ArgobytesDeployer
// deploy contracts and burn gas tokens
// only set gas_token if the contract is large and gas prices are high
// LGT's deploy helper only buys (we might have our own tokens)
contract ArgobytesProxyFactory is IArgobytesProxyFactory, LiquidGasTokenUser {
    // build a proxy for msg.sender with owner-only auth
    // auth can be changed later by the owner
    function buildVaultAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt
    ) public override payable returns (address deployed) {
        deployed = buildVaultAndFree(
            gas_token_amount,
            require_gas_token,
            salt,
            IArgobytesAuthority(0),
            msg.sender
        );
    }

    // build a proxy for msg.sender with progra
    function buildVaultAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority
    ) public override payable returns (address deployed) {
        deployed = buildVaultAndFree(
            gas_token_amount,
            require_gas_token,
            salt,
            first_authority,
            msg.sender
        );
    }

    function buildVaultAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        IArgobytesAuthority first_authority,
        address first_owner
    ) public override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        freeGasTokens(gas_token_amount, require_gas_token);

        deployed = address(
            new ArgobytesProxy{salt: salt}(first_owner, first_authority)
        );

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }

    function deploy2(
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

    function deploy2AndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) public override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        freeGasTokens(gas_token_amount, require_gas_token);

        deployed = deploy2(salt, bytecode, extradata);

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }

    function existing_or_deploy2(bytes32 salt, bytes memory bytecode)
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
