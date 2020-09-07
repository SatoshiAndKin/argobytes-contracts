// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

interface IDiamondCut {
    function deploy2AndFree(
        address gas_token,
        bytes32 salt,
        bytes calldata initcode
    ) external payable returns (address deployed);

    /*
    function deploy2AndDiamondCutAndFree(
        address gas_token,
        bytes32 salt,
        bytes calldata facet_initcode,
        bytes calldata facet_sigs,
        address _init,
        bytes calldata _calldata
    ) external payable returns (address deployed);
    */

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// This argument is tightly packed for gas efficiency
    /// That means no padding with zeros.
    /// Here is the structure of _diamondCut:
    /// _diamondCut = [
    ///     abi.encodePacked(facet, sel1, sel2, sel3, ...),
    ///     abi.encodePacked(facet, sel1, sel2, sel4, ...),
    ///     ...
    /// ]
    /// facet is the address of a facet
    /// sel1, sel2, sel3 etc. are four-byte function selectors.
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        bytes[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    function diamondCutAndFree(
        address gas_token,
        bytes[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external payable;

    event Deploy(address deployed);
    event DiamondCut(bytes[] _diamondCut, address _init, bytes _calldata);
}
