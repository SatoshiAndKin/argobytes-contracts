/*
    Copyright 2019 dYdX Trading Inc.
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    https://github.com/dydxprotocol/solo/blob/2d8454e02702fe5bc455b848556660629c3cad36/contracts/protocol/external/IDyDxCallee.sol
*/

pragma solidity 0.8.7;

import {DyDx_Account} from "./DyDx_Account.sol";

/**
 * @title IDyDxCallee
 * @author dYdX
 *
 * Interface that Callees for Solo must implement in order to ingest data.
 */
abstract contract DyDx_IDyDxCallee {
    // ============ Public Functions ============

    /**
     * Allows users to send this contract arbitrary data.
     *
     * @param  sender       The msg.sender to Solo
     * @param  accountInfo  The account from which the data is being sent
     * @param  data         Arbitrary data given by the sender
     */
    function callFunction(
        address sender,
        DyDx_Account.Info memory accountInfo,
        bytes memory data
    ) public virtual;
}
