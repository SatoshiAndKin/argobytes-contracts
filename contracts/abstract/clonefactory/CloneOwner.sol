// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

abstract contract CloneOwner {
    /*
    Get the clone's owner.

    An immutable keyword would be nice here, but because of how we make our clones, we don't have a constructor

    This requires that the contract put the address as the last 20 bytes of their bytecode!

    TODO: i'm sure this could be **much** better
    */
    function owner() public view returns (address ownerAddress) {
        // i think we need to use "this" to properly handle delegatecalls. codesize and codecopy weren't working right
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
