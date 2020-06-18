// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.6.10;

interface IGasTokenBurner {
    /**
     * @notice Mint `amount` gas tokens for this contract.
     * TODO: is this safe? what if someone passes a malicious address here?
     */
    function mintGasToken(address gas_token, uint256 amount) external;
}
