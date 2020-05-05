/*

    Copyright 2020 Kollateral LLC.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    Updated to 0.6.4 by Satoshi & Kin, Inc. These are functional changes and so are not under copyright.

*/

pragma solidity ^0.6.4;

import {IInvocationHook} from "./IInvocationHook.sol";

abstract contract IInvoker is IInvocationHook {
    function invoke(address invokeTo, bytes calldata invokeData, address tokenAddress, uint256 tokenAmount)
    external
    payable
    virtual;

    function invokeCallback() external virtual;

    function poolReward() external virtual view returns (uint256);

    function poolRewardAddress(address tokenAddress) external virtual view returns (address);

    function platformReward() external virtual view returns (uint256);

    function platformVaultAddress() external virtual view returns (address);

    function isTokenAddressRegistered(address tokenAddress) public virtual view returns (bool);

    function totalLiquidity(address tokenAddress) external virtual view returns (uint256);
}
