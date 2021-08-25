// SPDX-License-Identifier: MPL-2.0
// TODO: WETH10 is out. it is backwards compatible with 9, but has more features. do we care about any of them?
pragma solidity 0.8.7;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {IWETH9} from "contracts/external/weth9/IWETH9.sol";

contract Weth9Action {
    IWETH9 public immutable weth;

    // this function must be able to receive ether if it is expected to wrap it
    receive() external payable {}

    constructor(IWETH9 _weth) {
        weth = _weth;
    }

    function unwrapAll(address payable to) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 amount = weth.balanceOf(address(this)) - 1;

        // require(balance > 0, "Weth9Action:unwrapAllTo: no amount");

        // convert all WETH into ETH
        weth.withdraw(amount);
    }

    function unwrapAllTo(address payable to) external {
        // leave 1 wei behind for gas savings on future calls
        uint256 amount = weth.balanceOf(address(this)) - 1;

        // require(amount > 0, "Weth9Action:unwrapAllTo: no amount");

        // convert all WETH into ETH
        weth.withdraw(amount);

        // send ETH to the next contract
        Address.sendValue(to, amount);
    }

    /// @dev you must delegatecall this
    function wrapAll() external payable {
        // leave 1 wei behind for gas savings on future calls
        uint256 amount = address(this).balance - 1;

        // require(balance > 0, "Weth9Action:wrapAllTo: no balance");

        // convert all ETH into WETH
        weth.deposit{value: amount}();
    }

    function wrapAllTo(address to) external payable {
        // leave 1 wei behind for gas savings on future calls
        uint256 amount = address(this).balance - 1;

        // require(balance > 0, "Weth9Action:wrapAllTo: no balance");

        // convert all ETH into WETH
        weth.deposit{value: amount}();

        // send WETH to the next contract
        // we know _WETH9 returns a bool, so no need to use safeTransfer
        require(weth.transfer(to, amount), "Weth9Action.wrapAllTo: transfer failed");
    }
}
