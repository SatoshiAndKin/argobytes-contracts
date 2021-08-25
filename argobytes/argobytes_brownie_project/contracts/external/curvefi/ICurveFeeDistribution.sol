// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.6.12;

interface ICurveFeeDistribution {
    function claim(address) external returns (uint256);
}
