/* Like https://github.com/makerdao/multicall, but compatible with DyDx calls */
// i thought about adding a helper function to transfer out stuck funds, but callFunction already looks generic enough

pragma solidity 0.8.5;

import {DyDx_IDyDxCallee, DyDx_Account} from "./external/DyDx_IDyDxCallee.sol";

contract DyDxCalleeMulticall is DyDx_IDyDxCallee {
    struct Call {
        address target;
        bytes callData;
    }

    /**
     * Allows users to call arbitrary contracts.
     *
     * @param  sender       The msg.sender to Solo
     * @param  accountInfo  The account from which the data is being sent
     * @param  data         Arbitrary data given by the sender
     */
    function callFunction(
        address sender,
        DyDx_Account.Info memory accountInfo,
        bytes memory data
    ) public override {
        // we don't need to do anything with sender
        sender;

        // accountInfo is probably empty. we might want to use it though
        accountInfo;

        // parse data as an array of calls
        Call[] memory calls = abi.decode(data, (Call[]));

        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );

            // at first, i thought we should check the return for a magic string or something,
            // but now, i want to let this function be as open as possible
            ret;

            require(success);
        }
    }
}
