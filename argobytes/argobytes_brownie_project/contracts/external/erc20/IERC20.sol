// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.4;

import {SafeERC20} from "@OpenZeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@OpenZeppelin/token/ERC20/extensions/IERC20Metadata.sol";


// this does not extend IERC20 because the Transfer event would conflict
interface UnindexedIERC20 {
    function decimals() external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    // transfer event without indexes
    event Transfer(address from, address to, uint256 value);
}
