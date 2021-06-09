// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.4;

library BytesLib {
    function toBytes4(bytes memory input) internal pure returns (bytes4 output) {
        if (input.length == 0) {
            return 0x0;
        }

        assembly {
            output := mload(add(input, 4))
        }
    }
}
