// SPDX-License-Identifier: LGPL-3.0-or-later
// TODO: maybe better to just use the diamond standard EIP for upgradable contracts, but this works for now

pragma solidity 0.6.9;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {Address} from "@openzeppelin/utils/Address.sol";

contract Backdoor is AccessControl {
    using Address for address;

    bytes32 internal constant BACKDOOR_ROLE = keccak256("BACKDOOR_ROLE");

    /**
     * @notice Backdoor call to `to` with `value` wei and data `data`.
     */
    function backdoor_call(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory) {
        require(
            hasRole(BACKDOOR_ROLE, msg.sender),
            "Backdoor.backdoor_call: Caller does not have backdoor role"
        );

        bytes memory return_data = to.functionCallWithValue(
            data,
            value,
            "backdoor call failed"
        );

        // emit?
        return return_data;
    }

    /**
     * @notice Backdoor delegatecall to `to` with data `data`.
     */
    function backdoor_delegate_call(address to, bytes calldata data)
        external
        returns (bytes memory)
    {
        require(
            hasRole(BACKDOOR_ROLE, msg.sender),
            "Backdoor.backdoor_delegate_call: Caller does not have backdoor role"
        );

        (bool success, bytes memory return_data) = to.delegatecall(data);

        if (!success) {
            // TODO: include the return_data in the error
            revert("backdoor delegatecall failed");
        }

        // emit?
        return return_data;
    }
}
