// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

import {SafeERC20} from "@OpenZeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title https://eips.ethereum.org/EIPS/eip-20
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

/// @dev this does not extend IERC20 because the events would conflict
interface UnindexedIERC20 {
    /// @dev non-standard transfer event without indexes
    event Transfer(address from, address to, uint256 value);

    /// @dev non-standard approval event without indexes
    event Approval(address owner, address spender, uint256 value);
}
