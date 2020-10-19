// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;

/*
The MIT License (MIT)
Copyright (c) 2018 Murray Software, LLC.
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
//solhint-disable max-line-length
//solhint-disable no-inline-assembly

// TODO: CloneFactory16

import {Strings2} from "contracts/library/Strings2.sol";

contract CloneFactory {
    using Strings2 for address;

    function createClone(
        address target,
        bytes32 salt,
        address staticOwner
    ) internal returns (address result) {
        // TODO: is this cast necessary? does it pad without it?
        bytes20 targetBytes = bytes20(target);
        bytes20 staticOwnerBytes = bytes20(staticOwner);
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let clone := mload(0x40)

            // start of the contract
            mstore(
                clone,
                0x3d604180600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            // target contract that the clone delegates all calls to
            mstore(add(clone, 0x14), targetBytes)
            // end of the contract
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // add the hashed params to the end so we get a unique address from CREATE2
            // TODO: this might be a terrible idea. think more about it
            mstore(add(clone, 0x37), staticOwnerBytes)

            // deploy it
            // the contract and owner is 75 (0x4b) bytes long
            result := create2(0, clone, 0x4b, salt)
        }

        // TODO: quick and dirty debugging of isClone
        // (bool result2, address owner) = isClone(target, result);
        // revert(staticOwner.toString());
        // require(result2, "bad clone");
        // require(owner == staticOwner, "bad owner");
    }

    function isClone(address target, address query)
        internal
        view
        returns (bool result, address owner)
    {
        // TODO: is this cast necessary?
        bytes20 targetBytes = bytes20(target);
        bytes20 ownerBytes;

        assembly {
            let other := mload(0x40)

            // TODO: right now our contract is 55 bytes + 20 bytes for the owner address, but this will change if we use shorter addresses
            extcodecopy(query, other, 0, 75)

            // load 32 bytes
            // TODO: cut this down to 20 bytes
            ownerBytes := mload(add(other, 45))

            let clone := add(other, 75)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), targetBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            mstore(add(clone, 0x2d), ownerBytes)

            result := and(
                and(
                    // check that the first 32 bytes match
                    eq(mload(clone), mload(other)),
                    // check that the next 32 bytes match
                    eq(mload(add(clone, 32)), mload(add(other, 32)))
                ),
                // check that the last bytes match
                // TODO: if we use vanity addresses, this will be shorter!
                eq(mload(add(clone, 43)), mload(add(other, 43)))
            )
        }

        owner = address(ownerBytes);
    }
}
