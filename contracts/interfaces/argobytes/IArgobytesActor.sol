// SPDX-License-Identifier: You can't license an interface
// Do atomic actions and free LiquidGasToken (or compatible)
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

interface IArgobytesActor {
    struct Action {
        address payable target;
        bytes data;
        bool with_value;
    }

    function callActions(
        Action[] calldata actions
    ) external;
}
