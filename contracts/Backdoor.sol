// SPDX-License-Identifier: LGPL-3.0-or-later
// TODO: backdoor_static_call and backdoor_delegate_call
// TODO: maybe better to just use the diamond standard EIP for upgradable contracts, but this works for now

pragma solidity 0.6.9;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";

contract Backdoor is AccessControl {
    bytes32 internal constant BACKDOOR_ROLE = keccak256("BACKDOOR_ROLE");

    /**
     * @notice Backdoor call to `to` with `value` wei and data `data`.
     */
    function backdoor_call(address to, uint256 value, bytes calldata data) external returns (bytes memory) {
        // TODO: allow the use of GSN? seems like unnessary complexity
        require(hasRole(BACKDOOR_ROLE, msg.sender), "Backdoor.backdoor_call: Caller does not have backdoor role");

        // calls to self still seem unnecessary even for a backdoor
        require(to != address(this), "Backdoor.backdoor_call: calls to self are not allowed");

        (bool success, bytes memory return_data) = to.call{value: value}(data);

        if (!success) {
            // TODO: include the return_data in the error
            revert("backdoor call failed");
        }

        // emit?
        return return_data;
    }

    /**
     * @notice Backdoor delegatecall to `to` with data `data`.
     */
    function backdoor_delegate_call(address to, bytes calldata data) external returns (bytes memory) {
        // TODO: allow the use of GSN? seems like unnessary complexity
        require(hasRole(BACKDOOR_ROLE, msg.sender), "Backdoor.backdoor_delegate_call: Caller does not have backdoor role");

        // calls to self still seem unnecessary even for a backdoor
        require(to != address(this), "Backdoor.backdoor_delegate_call: calls to self are not allowed");

        (bool success, bytes memory return_data) = to.delegatecall(data);

        if (!success) {
            // TODO: include the return_data in the error
            revert("backdoor delegatecall failed");
        }

        // emit?
        return return_data;
    }
}
