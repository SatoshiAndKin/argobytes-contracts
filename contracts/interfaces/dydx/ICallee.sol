// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.1;
pragma experimental ABIEncoderV2;

import {DyDxTypes} from "./DyDxTypes.sol";

/**
 * @title ICallee
 * @author dYdX
 *
 * Interface that Callees for Solo must implement in order to ingest data.
 */
interface ICallee {
    /**
     * Allows users to send this contract arbitrary data.
     *
     * @param  sender       The msg.sender to Solo
     * @param  accountInfo  The account from which the data is being sent
     * @param  data         Arbitrary data given by the sender
     */
    function callFunction(
        address sender,
        DyDxTypes.AccountInfo memory accountInfo,
        bytes memory data
    ) external;
}
