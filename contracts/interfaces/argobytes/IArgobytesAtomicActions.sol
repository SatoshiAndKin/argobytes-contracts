// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

abstract contract IArgobytesAtomicActions {
    struct Action {
        address payable target;
        bytes data;
        bool with_value;
    }

    function atomicActions(bytes calldata encoded_actions) external virtual;

    function atomicTrades(
        address kollateral_invoker,
        address[] calldata tokens,
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external virtual payable;
}
