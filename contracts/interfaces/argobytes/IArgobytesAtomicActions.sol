// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

abstract contract IArgobytesAtomicActions {
    struct Action {
        address payable target;
        bytes data;
        bool with_value;
    }

    function atomicActions(Action[] calldata actions) external virtual payable;

    function atomicTrades(
        address kollateral_invoker,
        address[] calldata tokens,
        uint256 first_amount,
        Action[] calldata actions
    ) external virtual payable;
}
