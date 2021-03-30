// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import {Address} from "@OpenZeppelin/utils/Address.sol";

/**
 * @dev Collection of openzepplin's unreleased functions related to the address type
 */
library AddressLib {

    function uncheckedCall(
        address target,
        bool forward_value,
        bytes memory data,
        string memory errorMessage
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

        return _verifyCallResult(success, returndata, errorMessage);
    }

    /// @dev make sure to check Address.isContract(target) first!
    function uncheckedDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        // doing this all in assembly is a lot more efficient
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
