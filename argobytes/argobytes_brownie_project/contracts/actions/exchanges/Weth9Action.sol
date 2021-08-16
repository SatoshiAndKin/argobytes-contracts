// SPDX-License-Identifier: MPL-2.0
// TODO: WETH10 is out. it is backwards compatible with 9, but has more features. do we care about any of them?
pragma solidity 0.8.5;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {IWETH9} from "contracts/external/weth9/IWETH9.sol";

contract Weth9Action {
    IWETH9 public immutable weth;

    // this function must be able to receive ether if it is expected to wrap it
    receive() external payable {}

    constructor(IWETH9 _weth) {
        weth = _weth;
    }

    function wrap_all_to(address to) external payable {
        // leave 1 wei behind for gas savings on future calls
        uint256 balance = address(this).balance - 1;

        // require(balance > 0, "Weth9Action:wrap_all_to: no balance");

        // convert all ETH into WETH
        weth.deposit{value: balance}();

        // send WETH to the next contract
        // we know _WETH9 returns a bool, so no need to use safeTransfer
        require(weth.transfer(to, balance), "Weth9Action.wrap_all_to: transfer failed");
    }

    function unwrap_all_to(address payable to) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 balance = weth.balanceOf(address(this)) - 1;

        // require(balance > 0, "Weth9Action:unwrap_all_to: no balance");

        // convert all WETH into ETH
        weth.withdraw(balance);

        // send ETH to the next contract
        Address.sendValue(to, balance);
    }
}
