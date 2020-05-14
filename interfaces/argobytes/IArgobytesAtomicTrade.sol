pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

abstract contract IArgobytesAtomicTrade {
    // TODO: bytes calldata encoded_actions instead?
    // TODO: return the profit once i figure out how to do the gas token burning efficiently
    function atomicTrade(address[] calldata tokens, uint256 first_amount, bytes calldata encoded_actions)
        external payable virtual;
}
