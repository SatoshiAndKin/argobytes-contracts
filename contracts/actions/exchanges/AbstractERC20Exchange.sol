// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * There are multitudes of possible contracts for SoloArbitrage. AbstractExchange is for interfacing with ERC20.
 *
 * These contracts should also be written in a way that they can work with any flash lender
 *
 * Rewrite this to use UniversalERC20? I'm not sure its worth it. this is pretty easy to follow.
 */
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {SafeMath} from "@OpenZeppelin/math/SafeMath.sol";

import {
    IERC20,
    UniversalERC20,
    SafeERC20
} from "contracts/library/UniversalERC20.sol";

contract AbstractERC20Exchange {
    using Address for address;
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    // this contract must be able to receive ether if it is expected to return it
    receive() external payable {}

    /* just in case some token approve gets stuck non-zero and needs to be reset.
    
    I'll write a blog post about this one day, but all the tokens doing fancy things for front-running prevention have made this annoying.
    */
    function clearApproval(
        address token,
        address who
    ) external {
        IERC20(token).approve(who, 0);
    }

    // TODO: i dont think we actually need these modifiers. i think we always trade all the source token
    /// @dev after the function, send any remaining ether back to msg.sender
    modifier returnLeftoverEther() {
        _;

        uint256 balance = address(this).balance;

        if (balance > 0) {
            Address.sendValue(msg.sender, balance);
        }
    }

    /// @dev after the function, send any remaining tokens to an address
    modifier returnLeftoverToken(address token) {
        _;

        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance > 0) {
            IERC20(token).safeTransfer(msg.sender, balance);
        }
    }

    /// @dev after the function, send any remaining ether or tokens to an address
    modifier returnLeftoverUniversal(address token) {
        _;

        uint256 balance = IERC20(token).universalBalanceOf(address(this));

        if (balance > 0) {
            IERC20(token).universalTransfer(msg.sender, balance);
        }
    }
}
