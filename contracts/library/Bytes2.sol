// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity 0.7.1;

library Bytes2 {
    function toBytes4(bytes memory input) internal pure returns (bytes4 output) {
        if (input.length == 0) {
            return 0x0;
        }

        assembly {
            output := mload(add(input, 4))
        }
    }
}