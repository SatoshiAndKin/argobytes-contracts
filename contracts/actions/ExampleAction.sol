// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";
import {UniversalERC20} from "contracts/UniversalERC20.sol";

contract ExampleAction is AbstractERC20Exchange {
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

        if (to == address(0)) {
            token.universalTransfer(msg.sender, balance);
        } else {
            token.universalTransfer(to, balance);
        }

        burnGas(extra_gas);
    }

    function token_supported(address exchange, address token)
        public
        override
        returns (bool)
    {
        revert("ExampleAction.token_supported: unimplemented");
    }

    function getAmounts(
        address token_a,
        uint256 token_a_amount,
        address token_b
    ) external view returns (Amount[] memory) {
        bytes memory extra_data = "";

        return _getAmounts(token_a, token_a_amount, token_b, extra_data);
    }

    function newAmount(
        address maker_address,
        uint256 taker_wei,
        address taker_address,
        bytes memory extra_data
    ) public override view returns (Amount memory) {
        revert("ExampleAction.newAmount: unimplemented");
    }
}
