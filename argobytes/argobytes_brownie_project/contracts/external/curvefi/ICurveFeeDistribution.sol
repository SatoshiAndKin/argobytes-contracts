// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

interface ICurveFeeDistribution {
    function claim(address) external returns (uint256);
}
