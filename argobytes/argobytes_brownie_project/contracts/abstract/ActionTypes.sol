// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.5;

/// @title Common types for contracts that use actions
contract ActionTypes {
    enum CallType {
        DELEGATE,
        CALL,
        ADMIN
    }

    struct Action {
        address payable target;
        CallType call_type;
        bytes data;
    }
}
