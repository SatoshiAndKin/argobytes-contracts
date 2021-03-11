pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

contract ActionTypes {
    enum Call {
        DELEGATE,
        CALL,
        ADMIN
    }
}
