// SPDX-License-Identifier: MIT
//
// Based on https://github.com/CryptoManiacsZone/1split/blob/014d4a08ef746af4b4da053e9465927d151ec1fe/contracts/UniversalERC20.sol
// TODO: This could definitely be gas-golfed. For example, we check `amount == 0` in our functions and in OpenZepplin's
//
// this is probably going to cost more gas than calling different functions for ETH or tokens, but this is saving me a lot of time
// make it work, make it work right, make it work fast. gas counts as "fast"
//
// Copyright (c) 2020 CryptoManiacs
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity 0.7.4;

import {IERC20} from "@OpenZeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@OpenZeppelin/token/ERC20/SafeERC20.sol";

library ArgobytesERC20 {
    using SafeERC20 for IERC20;

    // if the current approval isn't enough, approve maxint
    function approveUnlimitedIfNeeded(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        // clear the allowance if once exists
        uint256 allowance = IERC20(token).allowance(address(this), to);

        if (allowance >= amount) {
            // no approval needed
            return;
        }

        if (allowance > 0) {
            // clear the existing allowance
            // not all tokens require settings allowance from non-zero, but plenty do
            IERC20(token).approve(to, 0);
        }

        // set infinite allowance
        // we could use OZ's safeApprove here, but it checks allowance, too
        // TODO: think more about this
        IERC20(token).approve(to, uint256(-1));
    }
}
