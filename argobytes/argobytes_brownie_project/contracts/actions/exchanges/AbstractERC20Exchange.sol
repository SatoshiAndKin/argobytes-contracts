// SPDX-License-Identifier: MPL-2.0
/*
 * There are multitudes of possible contracts for SoloArbitrage. AbstractExchange is for interfacing with ERC20.
 *
 * These contracts should also be written in a way that they can work with any flash lender
 *
 * Rewrite this to use UniversalERC20? I'm not sure its worth it. this is pretty easy to follow.
 */
pragma solidity 0.8.7;

import {IERC20} from "contracts/external/erc20/IERC20.sol";

contract AbstractERC20Exchange {
    /// @notice if a token approval gets stuck non-zero and needs to be reset.
    /// @dev I'll write a blog post about this one day, but all the tokens doing fancy things for front-running prevention have made this annoying.
    function clearApproval(address token, address who) external {
        IERC20(token).approve(who, 0);
    }
}
