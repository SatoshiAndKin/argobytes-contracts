// SPDX-License-Identifier: LGPL-3.0-or-later
// Deploy contracts using CREATE2.

pragma solidity 0.7.6;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {Strings2} from "./library/Strings2.sol";
import {ArgobytesProxy} from "./ArgobytesProxy.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";
import {CloneFactory} from "./abstract/clonefactory/CloneFactory.sol";

// TODO: what order should the events be in?
contract ArgobytesFactoryEvents {
    event NewDeploy(address indexed deployer, bytes32 salt, address deployed);
}

// TODO: do we actually want `bytes memory extradata`? it could be useful, but i don't use it yet
interface IArgobytesFactory {
    function createContract(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    function createContractAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    // createClone and createClones are inherited from CloneFactory

    function createCloneAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        address target,
        bytes32 salt,
        address immutable_owner
    ) external payable returns (address clone);

    function createClonesAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) external payable;

    function checkedCreateContract(bytes32 salt, bytes memory bytecode)
        external
        payable
        returns (address deployed);
}

// ArgobytesDeployer
// deploy contracts and burn gas tokens
// only set gas_token if the contract is large and gas prices are high
// LGT's deploy helper only buys (we might have our own tokens)
contract ArgobytesFactory is
    ArgobytesFactoryEvents,
    CloneFactory,
    IArgobytesFactory,
    LiquidGasTokenUser
{
    // createClone and createClones are inherited from CloneFactory

    function createCloneAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        address target,
        bytes32 salt,
        address immutable_owner
    ) external override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        // we could calculate gas costs for the deploy based on bytecode size, but that might change in the future
        freeGasTokensFrom(gas_token_amount, require_gas_token, msg.sender);

        return createClone(target, salt, immutable_owner);
    }

    function createClonesAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) external override payable {
        // since this deployment cost can be known, we free a specific amount tokens
        // we could calculate gas costs for the deploy based on bytecode size, but that might change in the future
        freeGasTokensFrom(gas_token_amount, require_gas_token, msg.sender);

        createClones(target, salts, immutable_owner);
    }

    // deploy a contract with CREATE2 and then call a function on it
    function createContract(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) public override payable returns (address deployed) {
        deployed = Create2.deploy(0, salt, bytecode);

        emit NewDeploy(msg.sender, salt, deployed);

        if (extradata.length > 0) {
            // TODO: call or delegatecall?
            (bool success, ) = deployed.call(extradata);
            require(success, "extradata call reverted");
        }
    }

    // free gas tokens, deploy a contract with CREATE2, and then call a function on it
    function createContractAndFree(
        uint256 gas_token_amount,
        bool require_gas_token,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) public override payable returns (address deployed) {
        // since this deployment cost can be known, we free a specific amount tokens
        // we could calculate gas costs for the deploy based on bytecode size, but that might change in the future
        freeGasTokensFrom(gas_token_amount, require_gas_token, msg.sender);

        deployed = createContract(salt, bytecode, extradata);

        emit NewDeploy(msg.sender, salt, deployed);

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }

    // deploy a contract if it doesn't already exist
    function checkedCreateContract(bytes32 salt, bytes memory bytecode)
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
                "ArgobytesFactory: BAD_DEPLOY_ADDRESS"
            );
        }
    }
}
