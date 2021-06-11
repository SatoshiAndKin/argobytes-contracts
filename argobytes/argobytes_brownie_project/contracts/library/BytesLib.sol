// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.4;

library BytesLib {
    /// @notice Return the first 4 bytes of `input`
    /// @dev Used to get the signature from calldata when bytes4 casting and msg.sig won't work
    function toBytes4(bytes memory input) internal pure returns (bytes4 output) {
        if (input.length == 0) {
            return 0x0;
        }

        assembly {
            output := mload(add(input, 4))
        }
    }
}
