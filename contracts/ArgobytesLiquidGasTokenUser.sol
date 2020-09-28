// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.1;

import {LiquidGasTokenUser} from "contracts/abstract/LiquidGasTokenUser.sol";

// TODO: i'm not sure this is right. think more about how auth and approvals can work for this
// for example, approving a bot to call this would let them do anything. we need more limits

contract ArgobytesLiquidGasTokenUser is LiquidGasTokenUser {
    // call is dangerous! be careful!
    function lgtCall(
        address free_gas_token_from,
        bool require_gas_token,
        address payable target,
        bytes calldata target_data,
        uint256 value
    ) external payable returns (bytes memory) {
        uint256 initial_gas = initialGas(free_gas_token_from != address(0));

        (bool success, bytes memory returndata) = target.call{value: value}(
            target_data
        );

        // TODO: gas golf where to put this
        // TODO: freeFrom?
        freeOptimalGasTokensFrom(
            initial_gas,
            require_gas_token,
            free_gas_token_from
        );

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
            revert("ArgobytesLiquidGasTokenUser.lgtCall failed");
        }
    }

    // delegatecall is extremely dangerous! be careful!
    function lgtDelegateCall(
        address free_gas_token_from,
        bool require_gas_token,
        address payable target,
        bytes calldata target_data
    ) external payable returns (bytes memory) {
        uint256 initial_gas = initialGas(free_gas_token_from != address(0));

        (bool success, bytes memory returndata) = target.delegatecall(
            target_data
        );

        // TODO: gas golf where to put this
        // TODO: freeFrom?
        freeOptimalGasTokensFrom(
            initial_gas,
            require_gas_token,
            free_gas_token_from
        );

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
            revert("ArgobytesLiquidGasTokenUser.lgtDelegateCall failed");
        }
    }
}
