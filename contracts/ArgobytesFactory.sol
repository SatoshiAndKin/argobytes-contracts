// SPDX-License-Identifier: LGPL-3.0-or-later
// Deploy contracts using CREATE2.
pragma solidity 0.7.6;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

contract ArgobytesFactoryEvents {
    event NewContract(address indexed deployer, bytes32 salt, address deployed);

    event NewClone(
        address indexed target,
        bytes32 salt,
        address indexed immutable_owner,
        address clone
    );
}

// TODO: do we actually want `bytes memory extradata`? it could be useful, but i don't use it yet
interface IArgobytesFactory {
    function createClone(
        address target,
        bytes32 salt,
        address immutable_owner
    ) external returns (address clone);

    function createClones(
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) external;
    
    function hasClone(
        address target,
        bytes32 salt,
        address immutableOwner
    ) external view returns (bool cloneExists, address cloneAddr);

    function createContract(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) external payable returns (address deployed);

    function checkedCreateContract(bytes32 salt, bytes memory bytecode)
        external
        payable
        returns (address deployed);

}


import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

contract CloneFactoryEvents {
}

contract ArgobytesFactory is
    ArgobytesFactoryEvents,
    IArgobytesFactory
{
    using Address for address;

    /*
    Create a very lightweight "clone" contract that delegates all calls to the `target` contract.

    Some contracts (such as curve's vote locking contract) only allow access from EOAs and from DAO-approved smart wallets.
    Transfers would bypass Curve's time-locked votes since you could just sell your smart wallet.
    People could still sell their keys, but that is dangerous behavior that also applies to EOAs.
    We would like our ArgobytesProxy clones to qualify for these contracts and so the smart wallet CANNOT be transfered.

    To accomplish this, the clone has the `immutable_owner` address appended to the end of its code. This data cannot be changed.
    If the target contract uses ArgobytesAuth (or compatible) for authentication, then ownership of this clone *cannot* be transferred.

    We originally allowed setting an authority here, but that allowed for some shenanigans.
    It may cost slightly more, but a user will have to send a second transaction if they want to set an authority.
    */
    function createClone(
        address target,
        bytes32 salt,
        address immutable_owner
    ) public override returns (address clone) {
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let code := mload(0x40)

            // start of the contract (+20 bytes)
            // 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            // the "0x41" below is the actual contract length
            mstore(
                code,
                0x3d604180600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            // target contract that the clone delegates all calls to (+20 bytes = 40)
            mstore(add(code, 0x14), shl(0x60, target))
            // end of the contract (+15 bytes = 55)
            mstore(
                add(code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // add the owner to the end (+20 bytes = 75)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            mstore(add(code, 0x37), shl(0x60, immutable_owner))

            // deploy it
            clone := create2(0, code, 75, salt)
        }

        // revert if the contract was already deployed
        require(clone != address(0), "create2 failed");

        emit NewClone(target, salt, immutable_owner, clone);
    }

    function createClones(
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) public override {
        for (uint i = 0; i < salts.length; i++) {
            createClone(target, salts[i], immutable_owner);
        }
    }

    /**
     * @dev Check if a clone has already been created for the given arguments.
     */
    function hasClone(
        address target,
        bytes32 salt,
        address immutableOwner
    ) public override view returns (bool cloneExists, address cloneAddr) {
        bytes32 bytecodeHash;
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let code := mload(0x40)

            // start of the contract (+20 bytes)
            // 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            // the "0x41" below is the actual contract length
            mstore(
                code,
                0x3d604180600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            // target contract that the clone delegates all calls to (+20 bytes = 40)
            mstore(add(code, 0x14), shl(0x60, target))
            // end of the contract (+15 bytes = 55)
            mstore(
                add(code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // add the owner to the end (+20 bytes = 75)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            mstore(add(code, 0x37), shl(0x60, immutableOwner))

            bytecodeHash := keccak256(code, 75)
        }

        // TODO: do this all here in assembly? the compiler should be smart enough to not have any savings doing that
        cloneAddr = Create2.computeAddress(salt, bytecodeHash);

        cloneExists = cloneAddr.isContract();
    }

    // openzeppelin and optionality do this differently. what is cheaper?
    function isClone(address target, address query)
        public
        view
        returns (bool result, address owner)
    {
        assembly {
            let other := mload(0x40)

            // TODO: right now our contract is 45 bytes + 20 bytes for the owner address, but this will change if we use shorter addresses
            extcodecopy(query, other, 0, 65)

            // load 32 bytes (12 of the bytes will be ignored)
            // the last 20 bytes of this are the owner's address
            owner := mload(add(other, 33))

            let clone := add(other, 65)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), shl(0x60, target))
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // we could copy the owner, but theres no real need
            // mstore(add(clone, 0x2d), owner)

            result := and(
                // check bytes 0 through 31
                eq(mload(clone), mload(other)),
                // check bytes 13 through 44
                // we don't care about checking the owner bytes (45 through 65)
                eq(mload(add(clone, 13)), mload(add(other, 13)))
            )
        }
    }

    /**
     * @dev deploy a contract with CREATE2 and then call a function on it
     */
    function createContract(
        bytes32 salt,
        bytes memory bytecode,
        bytes memory extradata
    ) public override payable returns (address deployed) {
        deployed = Create2.deploy(msg.value, salt, bytecode);

        emit NewContract(msg.sender, salt, deployed);

        if (extradata.length > 0) {
            (bool success, ) = deployed.call(extradata);
            require(success, "ArgobytesFactory !extradata");
        }
    }

    /**
     * @dev deploy a contract if it doesn't already exist
     */
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
                Create2.deploy(msg.value, salt, bytecode) == deployed,
                "ArgobytesFactory !create2"
            );
        }
    }
}
