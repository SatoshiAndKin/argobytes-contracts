// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {AddressLib} from "contracts/library/AddressLib.sol";

/// @title Call multiple contraacts
/** @dev
 *  Calling just one function on another contract isn't very exciting; you can already do that with your EOA.
 *  The ArgobytesMulticall contract's `callActions` function takes a list of multiple contract addresses and functions.
 *  If any fail, the whole thing reverts.
 *
 *  This contract is a key part of some action contracts. (See ArgobytesTrader.sol)
 *
 *  This is similar to [MakerDAO's multicall](https://github.com/makerdao/multicall) but it discards the result
 *
 *  If you need more complex ways to call multiple actions and move ETH around, you probably just want to write an action contract.
 */
contract ArgobytesMulticall {
    struct Action {
        address target;
        bool send_balance;
        bytes data;
    }

    /// @notice Call arbitrary actions
    /// @dev setup approvals or transfer tokens to the actions before calling this function
    function callActions(Action[] memory actions) external {
        // an action can do whatever it wants (liquidate, swap, refinance, etc.)
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].send_balance) {
                AddressLib.functionCallWithBalance(actions[i].target, actions[i].data);
            } else {
                AddressLib.functionCall(actions[i].target, actions[i].data);
            }
        }
    }
}
