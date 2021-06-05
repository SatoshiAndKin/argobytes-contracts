// SPDX-License-Identifier: MPL-2.0
// Deploy contracts using CREATE2.
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

contract ArgobytesFactory19 {
    event NewClone(address indexed target, bytes32 salt, address indexed immutable_owner, address clone);

    function createClone19(address target, bytes32 salt) public returns (address clone) {
        return createClone19(target, salt, msg.sender);
    }

    /*
    Create a very lightweight "clone" contract that delegates all calls to the `target` contract.

    The target's address MUST start with a zero byte (like 0x00...)! Why? To get the proxy byetcode to 64 bytes.
    If it were larger by 1 byte, this function would cost more gas.

    Additionally, you should get as many zero bytes in the target address as possible.
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
        address target,
        bytes32 salt,
        address immutable_owner
    ) public returns (address clone) {
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let code := mload(0x40)

            // start of the contract (20 bytes)
            // the first 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            // TODO: DOCUMENT the "2c" at the start
            // TODO: document the "72" at the end
            mstore(code, 0x3d604080600a3d3981f3363d3d373d3d3d363d72000000000000000000000000)
            // target contract that the clone delegates all calls to (20+19 = 39 bytes)
            // addresses are 20 bytes, but we require the use of create2 salts to get a 19 byte address
            // everything is accessed in 32 byte chunks, so we need to shift it by 32-(20-1) bytes (104 bits)
            // lots of devs use hex, but I just don't think quickly in hex so I use decimal.
            mstore(add(code, 20), shl(104, target))
            // end of the contract (39+15 bytes = 54)
            // TODO: document the "2a" in here
            mstore(add(code, 39), 0x5af43d82803e903d91602a57fd5bf30000000000000000000000000000000000)
            // finally, add the owner to the end (54+20 bytes = 74)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            // addresses are 20 bytes and everything is accessed in 32 byte chunks, so we need to shift it by 32-(20) bytes (96 bits)
            mstore(add(code, 54), shl(96, immutable_owner))

            // deploy it
            clone := create2(0, code, 74, salt)
        }

        // revert if the contract was already deployed
        require(clone != address(0), "create2 failed");

        emit NewClone(target, salt, immutable_owner, clone);
    }

    function createClone19s(address target, bytes32[] calldata salts) public {
        createClone19s(target, salts, msg.sender);
    }

    function createClone19s(
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) public {
        for (uint256 i = 0; i < salts.length; i++) {
            createClone19(target, salts[i], immutable_owner);
        }
    }

    /**
     * @dev Check if a clone has already been created for the given arguments.
     */
    function clone19Exists(
        address target,
        bytes32 salt,
        address immutableOwner
    ) public view returns (bool exists, address cloneAddr) {
        bytes32 bytecodeHash;
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let code := mload(0x40)

            // start of the contract (20 bytes)
            // 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            // this is the same as the official contract except the contract length is 20 bytes longer
            mstore(code, 0x3d604080600a3d3981f3363d3d373d3d3d363d72000000000000000000000000)
            // target contract that the clone delegates all calls to (20+19 = 39 bytes)
            mstore(add(code, 20), shl(104, target))
            // end of the contract (39+15 = 54 bytes)
            mstore(add(code, 39), 0x5af43d82803e903d91602a57fd5bf30000000000000000000000000000000000)
            // add the owner to the end (54+20 = 74 bytes)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            mstore(add(code, 54), shl(96, immutableOwner))

            bytecodeHash := keccak256(code, 75)
        }

        // TODO: do this all here in assembly? the compiler should be smart enough to not have any savings doing that
        cloneAddr = Create2.computeAddress(salt, bytecodeHash);

        exists = Address.isContract(cloneAddr);
    }

    // openzeppelin and optionality do this differently. what is cheaper?
    function isClone(address target, address query) public view returns (bool result, address owner) {
        assembly {
            let other := mload(0x40)

            // right now our contract is 44 bytes + 20 bytes for the owner address, but this will change if we use shorter addresses
            extcodecopy(query, other, 0, 64)

            // the last 20 bytes of the contract is the owner's address
            // the whole contract is 64 bytes long (64-32=32 bytes to load)
            // we have to load 32 bytes at a time (the first 12 of the bytes will be ignored. the last 20 are the address)
            owner := mload(add(other, 32))

            // other is 64 bytes long. store clone right after it in memory
            // TODO: use mload(0x40) instead?
            let clone := add(other, 64)
            mstore(clone, 0x363d3d373d3d3d363d7200000000000000000000000000000000000000000000)
            // target is a 19 byte address. (32-19) * 8 = 104
            mstore(add(clone, 10), shl(104, target))
            mstore(add(clone, 29), 0x5af43d82803e903d91602a57fd5bf30000000000000000000000000000000000)
            // we could copy the owner, but theres no real need
            // mstore(add(clone, 44), owner)

            result := and(
                // check bytes 0 through 31
                eq(mload(clone), mload(other)),
                // check bytes 12 through 43
                // we don't care about checking the owner bytes (44 through 64) because they are immutable and part of the target's address
                eq(mload(add(clone, 12)), mload(add(other, 12)))
            )
        }
    }

    /**
     * @dev deploy a contract if it doesn't already exist
     * @dev if you want to simply deploy a contract, use the SingletonFactory (eip-2470)
     */
    function checkedCreateContract(bytes32 salt, bytes memory bytecode) external payable returns (address deployed) {
        deployed = Create2.computeAddress(salt, keccak256(bytecode));

        if (!Address.isContract(deployed)) {
            // deployed doesn't exist. create it
            require(Create2.deploy(msg.value, salt, bytecode) == deployed, "ArgobytesFactory19 !checkedCreateContract");
        }
    }
}
