// SPDX-License-Identifier: MPL-2.0
// TODO: WETH10 is out. it is backwards compatible with 9, but has more features. do we care about any of them?
pragma solidity 0.8.4;

import {Address} from "@OpenZeppelin/utils/Address.sol";

import {IWETH9} from "contracts/external/weth9/IWETH9.sol";

contract Weth9Action {
    // this function must be able to receive ether if it is expected to wrap it
    receive() external payable {}

    // there is no need for returnLeftoverEther. this will always convert everything
    function wrap_all_to(address weth, address to) external payable {
        uint256 balance = address(this).balance;

        // require(balance > 0, "Weth9Action:wrap_all_to: no balance");

        // convert all ETH into WETH
        IWETH9(weth).deposit{value: balance}();

        // send WETH to the next contract
        // we know _WETH9 returns a bool, so no need to use safeTransfer
        require(IWETH9(weth).transfer(to, balance), "Weth9Action.wrap_all_to: transfer failed");
    }

    // there is no need for returnLeftoverToken. this will always convert everything
    function unwrap_all_to(address weth, address payable to) external {
        uint256 balance = IWETH9(weth).balanceOf(address(this));

        // require(balance > 0, "Weth9Action:unwrap_all_to: no balance");

        // convert all WETH into ETH
        IWETH9(weth).withdraw(balance);

        // send ETH to the next contract
        Address.sendValue(to, balance);
    }
}
