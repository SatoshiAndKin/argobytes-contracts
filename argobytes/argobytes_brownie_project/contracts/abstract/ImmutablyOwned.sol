// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

error AccessDenied();

/// @title A contract with the owner's address appended to the end
/// @dev In order to set the owner, contracts using this abstract need to be deployed with something like ArgobytesFactory19
abstract contract ImmutablyOwned {
    /// @dev revert if sender is not the owner
    modifier onlyOwner() {
        if (owner() != msg.sender) {
            revert AccessDenied();
        }
        _;
    }

    /// @notice Get the contract's immutable owner
    /// @dev An immutable keyword would be nice here, but because of how ArgobytesFactory19 makes our clones, we don't have a standard constructor
    /// @dev The contract must put the address as the last 20 bytes of their bytecode!
    /// @dev TODO: i'm sure this could be **much** better
    function owner() public view returns (address ownerAddress) {
        // we need to use "this" to properly handle delegatecalls
        // otherwise, codesize and codecopy point to the wrong contract
        address thisAddress = address(this);

        assembly {
            // retrieve the size of the code
            let size := extcodesize(thisAddress)

            // get the last 32 bytes of code
            extcodecopy(thisAddress, ownerAddress, sub(size, 32), 32)

            // load the code into the owner address
            ownerAddress := mload(ownerAddress)
        }
    }
}
