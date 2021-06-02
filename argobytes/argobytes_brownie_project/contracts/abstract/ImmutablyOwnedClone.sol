// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.4;

abstract contract ImmutablyOwnedClone {
    modifier onlyOwner() {
        require(owner() == msg.sender, "!owner");
        _;
    }

    /*
    Get the clone's owner.

    An immutable keyword would be nice here, but because of how we make our clones, we don't have a constructor

    This requires that the contract put the address as the last 20 bytes of their bytecode!

    TODO: i'm sure this could be **much** better
    */
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
