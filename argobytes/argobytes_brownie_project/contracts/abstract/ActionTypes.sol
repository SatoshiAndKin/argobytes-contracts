// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.6.12;

/// @title Common types for contracts that use actions
contract ActionTypes {
    enum CallType {
        DELEGATE,
        CALL,
        ADMIN
    }

    struct Action {
        address target;
        CallType call_type;
        bool send_balance;
        bytes data;
    }
}
