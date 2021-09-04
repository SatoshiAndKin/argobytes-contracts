// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IERC20, SafeERC20} from "contracts/external/erc20/SafeERC20.sol";

import {AbstractERC20Exchange} from "./AbstractERC20Exchange.sol";

// this might not be as gas efficient as doing the integrtaion off chain, but that is more work
interface CurveSwaps {
    function exchange(
        address pool,
        IERC20 from,
        IERC20 to,
        uint256 amount,
        uint256 expected,
        address receiver
    ) payable external returns(uint256);
}

contract CurveFiAction is AbstractERC20Exchange {
    using SafeERC20 for IERC20;

    CurveSwaps immutable curve_swaps;

    /// @notice get curve_swaps from https://curve.readthedocs.io/registry-exchanges.html
    constructor(CurveSwaps _curve_swaps) public {
        curve_swaps = _curve_swaps;
    }

    /// @notice trade the full balance on curve
    function trade(
        address pool,
        IERC20 src_token,
        IERC20 dest_token,
        uint256 dest_min_tokens,
        address to
    ) external {
        // Use the full balance of tokens
        // TODO: leave 1 wei behind for gas savings on future calls
        uint256 src_amount = src_token.balanceOf(address(this)) - 1;

        // TODO: efficient way to do infinite approvals? what is most gas efficient now?
        // we do safeApprove because this might be USDT or PAXG (or similarly broken ERC-20)
        src_token.safeApprove(address(curve_swaps), src_amount);

        // do the trade
        curve_swaps.exchange(pool, src_token, dest_token, src_amount, dest_min_tokens, to);
    }
}
