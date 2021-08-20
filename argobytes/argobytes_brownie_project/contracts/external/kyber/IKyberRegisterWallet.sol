// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.8.7;

/// @notice https://developer.kyber.network/docs/Integrations-FeeSharing/
interface IKyberRegisterWallet {
    function registerWallet(address wallet) external;
}
