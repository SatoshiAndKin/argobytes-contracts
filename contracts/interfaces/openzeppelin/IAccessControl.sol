// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.0;

interface IAccessControl {
    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function getRoleMember(bytes32 role, uint256 index)
        external
        view
        returns (address);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}
