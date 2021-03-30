// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.3;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {UniversalERC20} from "contracts/library/UniversalERC20.sol";

contract ExampleAction {
    using UniversalERC20 for IERC20;

    // some simple storage used for burning gas
    uint256 public c = 1;

    // https://github.com/matnad/liquid-gas-token/blob/35638bad1fab0064575913f0e7130d9b5f37332a/contracts/LgtHelper.sol#L15
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

    function noop() public payable returns (bool) {
        return true;
    }

    function sweep(
        address payable to,
        IERC20 token,
        uint256 extra_gas
    ) public payable {
        uint256 balance = token.universalBalanceOf(address(this));

        token.universalTransfer(to, balance);

        burnGas(extra_gas);
    }
}
