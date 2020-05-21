pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;


abstract contract IArgobytesAtomicTrade {
    struct Action {
        address payable target;
        bytes data;
    }

    function atomicTrade(
        address[] calldata tokens,
        uint256 first_amount,
        bytes calldata encoded_actions
    ) external virtual payable;
}
