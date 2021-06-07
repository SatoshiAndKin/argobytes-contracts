// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";

error BadCall(address target, bytes data, bytes errordata);
error BadDelegateCall(address target, bytes data, bytes errordata);

/// @title Similar to OpenZepplin's functions related to the address type
library AddressLib {
    /// @dev make sure to check Address.isContract(target) first, because this function does not!
    function uncheckedCall(
        address target,
        bool forward_value,
        bytes memory data
    ) internal returns (bytes memory) {
        bool success;
        bytes memory returndata;

        // solhint-disable-next-line avoid-low-level-calls
        if (forward_value) {
            // TODO: use msg.balance instead?
            (success, returndata) = target.call{value: msg.value}(data);
        } else {
            (success, returndata) = target.call(data);
        }

        if (success) {
            return returndata;
        } else {
            revert BadCall(target, data, returndata);
        }
    }

    /// @dev make sure to check Address.isContract(target) first, because this function does not!
    function uncheckedDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        // doing this all in assembly is a lot more efficient
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);

        if (success) {
            return returndata;
        } else {
            revert BadDelegateCall(target, data, returndata);
        }
    }
}
