// SPDX-License-Identifier: MPL-2.0

pragma solidity 0.8.7;

error CallReverted(address target, bytes data, bytes errordata);
error Create2Failed(bytes32 salt);
error InvalidTarget(address target);
error NoBytecode();

/// @title Helper functions for addresses
library AddressLib {
    /**
     * @notice Deploy a contract using `CREATE2`
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     */
    function deploy(bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        if (bytecode.length == 0) {
            revert NoBytecode();
        }

        // TODO: document this
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (addr == address(0)) {
            revert Create2Failed(salt);
        }
    }

    /// @dev Calculate the address that `CREATE2` will give
    function deployAddress(
        bytes32 salt,
        bytes32 bytecode_hash,
        address deployer
    ) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecode_hash)))));
    }

    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        // further discussion here: https://github.com/ethereum/solidity/issues/4834
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /// @dev call a function and discard the returndata
    function functionCall(address target, bytes memory data) internal returns (bytes memory returndata) {
        if (!isContract(target)) {
            revert InvalidTarget(target);
        }

        bool success;
        (success, returndata) = target.call(data);

        if (!success) {
            revert CallReverted(target, data, returndata);
        }
    }

    /// @dev call a function and discard the returndata
    function functionCallWithBalance(address target, bytes memory data) internal returns (bytes memory returndata) {
        if (!isContract(target)) {
            revert InvalidTarget(target);
        }

        bool success;
        (success, returndata) = target.call{value: address(this).balance}(data);

        if (!success) {
            revert CallReverted(target, data, returndata);
        }
    }
}
