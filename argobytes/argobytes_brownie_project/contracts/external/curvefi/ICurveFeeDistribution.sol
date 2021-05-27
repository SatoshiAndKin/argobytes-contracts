// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.4;

interface ICurveFeeDistribution {
    function claim(address) external returns (uint256);
}
