// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;


abstract contract IArgobytesAtomicTrade {
    struct Action {
        address payable target;
        bytes data;
    }

    function atomicTrade(
        address kollateral_invoker,
        address[] calldata tokens,
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external virtual payable;
}
