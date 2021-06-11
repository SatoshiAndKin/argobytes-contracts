// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.5;

import {IERC20, UniversalERC20} from "contracts/library/UniversalERC20.sol";

error FancyError(bool is_true, uint256 amount, string message);

contract ExampleAction {
    using UniversalERC20 for IERC20;

    /// @dev some simple storage used for burning gas
    uint256 public c = 1;

    /// @notice waste gas
    /// @dev https://github.com/matnad/liquid-gas-token/blob/35638bad1fab0064575913f0e7130d9b5f37332a/contracts/LgtHelper.sol#L15
    function burnGas(uint256 burn) public returns (uint256 burned) {
        uint256 start = gasleft();
        assert(start > burn + 200);
        uint256 end = start - burn;
        while (gasleft() > end + 5000) {
            // set storage. this is relatively expensive
            c++;
        }
        while (gasleft() > end) {
            // loop until we get to our actual end goal. this is cheap
        }
        burned = start - gasleft();
    }

    function fail() public payable {
        revert("ExampleAction: fail function always reverts");
    }

    function failFancy() public payable {
        revert FancyError(true, 1, "ExampleAction: fail function always reverts");
    }

    function noop() public payable returns (bool) {
        return true;
    }

    function sweep(
        address payable to,
        IERC20 token,
        uint256 extra_gas
    ) public payable {
        uint256 balance = token.universalBalanceOf(address(this));

        if (to != address(this)) {
            token.universalTransfer(to, balance);
        }

        burnGas(extra_gas);
    }
}
