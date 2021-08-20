// SPDX-License-Identifier: MPL-2.0
// Deploy contracts using CREATE2.
pragma solidity 0.8.7;

import {AddressLib, Create2Failed} from "contracts/library/AddressLib.sol";

/// @title A factory for proxy contracts with immutable owners and targets with 19 bytes addresses.
/// @author Satoshi & Kin, Inc.
/// @dev Use ERADICATE2 or similar for finding salts
contract ArgobytesFactory19 {
    event NewClone(address indexed target, bytes32 salt, address indexed immutable_owner, address clone);

    /// @dev Build the bytecode for a EIP-1167 proxy contract with a 19 byte target address
    function _cloneBytecode(address target19, address immutable_owner) internal pure returns (bytes memory code) {
        assembly {
            // start of the contract (20 bytes)
            // the first 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            mstore(code, 0x3d604080600a3d3981f3363d3d373d3d3d363d72000000000000000000000000)
            // target contract that the clone delegates all calls to (20+19 = 39 bytes)
            // addresses are 20 bytes, but we require the use of create2 salts to get a 19 byte address
            // everything is accessed in 32 byte chunks, so we need to shift it by 32-(20-1) bytes (104 bits)
            // lots of devs use hex, but I just don't think quickly in hex so I use decimal.
            mstore(add(code, 20), shl(104, target19))
            // end of the contract (39+15 bytes = 54)
            // TODO: document the "2a" in here
            mstore(add(code, 39), 0x5af43d82803e903d91602a57fd5bf30000000000000000000000000000000000)
            // finally, add the owner to the end (54+20 bytes = 74)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            // addresses are 20 bytes and everything is accessed in 32 byte chunks, so we need to shift it by 32-(20) bytes (96 bits)
            mstore(add(code, 54), shl(96, immutable_owner))
        }
    }

    /// @notice Check if a clone is already deployed
    function checkClone19(
        address target19,
        bytes32 salt,
        address immutable_owner
    ) public view returns (address clone, bool exists) {
        bytes memory bytecode = _cloneBytecode(target19, immutable_owner);

        bytes32 bytecode_hash;
        assembly {
            bytecode_hash := keccak256(bytecode, 74)
        }

        clone = AddressLib.deployAddress(salt, bytecode_hash, address(this));

        exists = AddressLib.isContract(clone);
    }

    /// @notice Create a proxy contract for `msg.sender`
    function createClone19(address target19, bytes32 salt) public returns (address clone) {
        return createClone19(target19, salt, msg.sender);
    }

    /// @notice Create a very lightweight "clone" or "proxy" contract that delegates all calls to the `target19` contract.
    /// @param target19 This address MUST start with a zero byte (like 0x00...)! Why? To get the proxy byetcode to 64 bytes.
    /// @param immutable_owner The unchangable owner for this proxy
    /** @dev
    If target were 20 bytes, this function would cost more gas to deploy.

    You should generate  a salt with as many zero bytes in the target address as possible.
    Each zero byte will slightly reduce the call cost.

    If the target contract uses ArgobytesAuth (or compatible) for authentication, then ownership of this clone *cannot* be transferred.
    Why? Some contracts (such as curve's vote locking contract) only allow access from EOAs and from DAO-approved smart wallets.
    Transfers would bypass Curve's time-locked votes since you could just sell your smart wallet.
    People could still sell their keys, but that is dangerous behavior that also applies to EOAs.
    We would like our ArgobytesProxy clones to qualify for these contracts and so the smart wallet CANNOT be transfered.
    To accomplish this, the clone has the `immutable_owner` address appended to the end of its code. This data cannot be changed.
    Of course, there will still have to be a DAO vote to allow the proxy.
    Also, because immutability is generally a good idea for smart contracts.

    We originally allowed setting an authority here, but that allowed for some shenanigans.
    It may cost slightly more, but a user will have to send a second transaction if they want to set an authority.
    */
    function createClone19(
        address target19,
        bytes32 salt,
        address immutable_owner
    ) public returns (address clone) {
        bytes memory bytecode = _cloneBytecode(target19, immutable_owner);

        assembly {
            // deploy it
            clone := create2(0, bytecode, 74, salt)
        }

        if (clone == address(0)) {
            // the salt isn't so helpful in this function, but from createClone19s it is helpful.
            revert Create2Failed(salt);
        }

        emit NewClone(target19, salt, immutable_owner, clone);
    }

    /// @notice Create multiple clone contracts for `msg.sender`.
    function createClone19s(address target, bytes32[] calldata salts) public {
        createClone19s(target, salts, msg.sender);
    }

    /// @notice Create multiple clone contracts.
    // TODO: return all the addresses
    function createClone19s(
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) public {
        uint256 num_clones = salts.length;
        for (uint256 i = 0; i < num_clones; i++) {
            // TODO: return the addresses
            createClone19(target, salts[i], immutable_owner);
        }
    }

    /// @notice Check if the `query` address is a clone for the given `target`.
    /// @dev because the owner is in the bytecode, it is part of the query address' generation and we don't need a param for it.
    function isClone(address target, address query) public view returns (bool is_clone) {
        uint256 query_size;
        assembly {
            query_size := extcodesize(query)
        }

        if (query_size != 64) {
            return false;
        }

        bytes memory query_code;
        assembly {
            // right now our contract is 44 bytes + 20 bytes for the owner address, but this will change if we use shorter addresses
            extcodecopy(query, query_code, 0, 64)
        }

        // set the owner to address 0 and then don't compare those bytes
        bytes memory expected_code = _cloneBytecode(target, address(0));

        assembly {
            is_clone := and(
                // check bytes 0 through 31
                eq(mload(expected_code), mload(query_code)),
                // check bytes 12 through 43
                // we don't care about checking the owner bytes (44 through 64) because they are immutable and part of the target's address
                eq(mload(add(expected_code, 12)), mload(add(query_code, 12)))
            )
        }
    }

    /// @notice Deploy a contract if it doesn't already exist
    /// @dev If you want to simply deploy a contract, use the SingletonFactory (eip-2470)
    function checkedCreateContract(bytes32 salt, bytes memory bytecode) external payable returns (address deployed) {
        deployed = AddressLib.deployAddress(salt, keccak256(bytecode), address(this));

        if (!AddressLib.isContract(deployed)) {
            // deployed doesn't exist. create it
            AddressLib.deploy(salt, bytecode);
        }
    }
}
