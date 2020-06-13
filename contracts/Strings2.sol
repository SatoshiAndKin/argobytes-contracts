// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.9;

library Strings2 {
    function toString(address x) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(x));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }

    /// @dev Get the revert message from a failed call
    /// @notice This is needed in order to get the human-readable revert message from a call
    /// @param return_data Response of the call
    /// @return Revert message string
    function toRevertString(bytes memory return_data)
        internal
        pure
        returns (string memory)
    {
        // this is what authereum does
        if (return_data.length < 68) {
            return "Strings2: Silent revert";
        }

        string memory revert_message;
        // this is what keep-network/tbtc does
        assembly {
            // A revert message is ABI-encoded as a call to Error(string)
            // Slicing the Error() signature (4 bytes) and Data offset (4 bytes)
            // leaves us with a pre-encoded string.
            // We also slice off the ABI-coded length of return_data (32).
            revert_message := add(return_data, 0x44)
        }

        return revert_message;
    }
}
