// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.0;

import {
    LiquidGasTokenUser
} from "contracts/LiquidGasTokenUser.sol";

contract ArgobytesLiquidGasTokenUser is LiquidGasTokenUser {

    // call is dangerous! be careful!
    function lgtCall(
        address gas_token,
        address payable target,
        bytes calldata target_data,
        uint256 value
    ) external payable returns (bytes memory) {
        uint256 initial_gas = initialGas(gas_token);

        (bool success, bytes memory returndata) = target.call{value: value}(
            target_data
        );

        // TODO: gas golf where to put this
        freeGasTokens(gas_token, initial_gas);

        if (success) {
            return returndata;
        }

        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert("ArgobytesLiquidGasTokenUser._externalDelegateCall failed");
        }
    }

    // delegatecall is extremely dangerous! be careful!
    function lgtDelegateCall(
        address gas_token,
        address payable target,
        bytes calldata target_data
    ) external payable returns (bytes memory) {
        uint256 initial_gas = initialGas(gas_token);

        (bool success, bytes memory returndata) = target.delegatecall(
            target_data
        );

        // TODO: gas golf where to put this
        freeGasTokens(gas_token, initial_gas);

        if (success) {
            return returndata;
        }

        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert("ArgobytesLiquidGasTokenUser._externalDelegateCall failed");
        }
    }
}
