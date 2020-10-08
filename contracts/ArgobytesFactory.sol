// SPDX-License-Identifier: LGPL-3.0-or-later
// deploy delegatecall proxies and free liquid gas tokens.

/*

"create" means using CREATE or CREATE2

"deploy" means using "create" and then calling some more functions

*/

pragma solidity 0.7.1;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {ArgobytesProxy} from "./ArgobytesProxy.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";
import {CloneFactory} from "./abstract/clonefactory/CloneFactory.sol";

// TODO: what order should the events be in?
contract ArgobytesFactoryEvents {
    event NewClone(
        address indexed original,
        address clone,
        bytes32 salt,
        address indexed first_owner,
        address indexed first_authority
    );

    event NewDeploy(address indexed deployer, bytes32 salt, address deployed);
}

// TODO: do we actually want `bytes memory extradata`? it could be useful, but i don't use it yet
interface IArgobytesFactory {
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

    function deployClone(
        address original,
        bytes32 salt,
        address first_owner,
        IArgobytesAuthority first_authority
    ) external;

    function existingOrCreate2(bytes32 salt, bytes memory bytecode)
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
    // deploy a contract with CREATE2 and then call a function on it
    function deploy(
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

        emit NewDeploy(msg.sender, salt, deployed);

        // refund any excess ETH
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
        }
    }

    // deploy and initialize a clone of a ArgobytesProxy (or other compatible) contract
    function deployClone(
        address original,
        bytes32 salt,
        address first_owner,
        IArgobytesAuthority first_authority
    ) external override {
        // TODO: do an ERC165 check on `original`?
        // TODO: get original out of state?

        address clone = createClone(original);

        emit NewClone(
            original,
            clone,
            salt,
            first_owner,
            address(first_authority)
        );

        ArgobytesProxy(payable(clone)).init(first_owner, first_authority);
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
                "ArgobytesFactory: BAD_DEPLOY_ADDRESS"
            );
        }
    }
}
