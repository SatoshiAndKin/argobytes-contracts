// SPDX-License-Identifier: LGPL-3.0-or-later
// deploy delegatecall proxies and free liquid gas tokens.

/*

"create" means using CREATE or CREATE2

"deploy" means using "create" and then calling some more functions

*/

pragma solidity 0.7.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "./abstract/LiquidGasTokenUser.sol";
import {Strings2} from "./library/Strings2.sol";
import {ArgobytesProxy} from "./ArgobytesProxy.sol";
import {IArgobytesAuthority} from "./ArgobytesAuthority.sol";
import {CloneFactory} from "./abstract/clonefactory/CloneFactory.sol";

// TODO: what order should the events be in?
contract ArgobytesFactoryEvents {
    event NewClone(
        address indexed target,
        bytes32 salt,
        address indexed immutable_owner,
        address clone
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
        address target,
        bytes32 salt,
        address immutable_owner
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
    using Strings2 for address;

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

    /*
    Deploy a very lightweight "clone" contract that delegates all calls to the `target` contract.

    We take target as a parameter to allow for easy upgrades or forks in the future.

    Some contracts (such as curve's vote locking contract) only allow access from EOAs and from DAO-approved smart wallets.
    Transfers would bypass Curve's time-locked votes since you could just sell your smart wallet.
    People could still sell their keys, but that is dangerous behavior that also applies to EOAs.
    We would like our ArgobytesProxy clones to qualify for these contracts and so the smart wallet CANNOT be transfered.

    To accomplish this, the clone has the `immutable_owner` address appended to the end of its code. This data cannot be changed.
    If the target contract uses ArgobytesAuth (or compatible) for authentication, then ownership of this clone *cannot* be transferred.

    We originally allowed setting an authority here, but that allowed for some shenanigans.
    It may cost slightly more, but a user will have to send a second transaction if they want to set an authority.
    */
    function deployClone(
        address target,
        bytes32 salt,
        address immutable_owner
    ) external override {
        // TODO: do an ERC165 check on `target`?

        // we used to allow setting authority here, but i can sense some security issues with that so we'll skip for now

        // TODO: maybe it would be better to do `salt = keccack256(immutable_owner, salt)`, but that makes using ERADICATE2 harder
        address clone = createClone(target, salt, immutable_owner);

        emit NewClone(target, salt, immutable_owner, clone);

        // TODO: remove this when done debugging
        // ArgobytesProxy proxy = ArgobytesProxy(payable(clone));
        // revert(immutable_owner.toString());
        // revert(proxy.owner().toString()); // expects 0x57ba9e012762bd38f3a9a2cd1178b5d79b1e266f
        // require(proxy.owner() == immutable_owner, "deployClone bad owner");
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
