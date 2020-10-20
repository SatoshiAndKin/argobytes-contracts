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
            let code := mload(0x40)

            // start of the contract (+20 bytes)
            // 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            mstore(
                code,
                0x3d604180600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            // target contract that the clone delegates all calls to (+20 bytes = 40)
            mstore(add(code, 0x14), targetBytes)
            // end of the contract (+15 bytes = 55)
            mstore(
                add(code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // add the owner to the end (+20 bytes = 75)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            mstore(add(code, 0x37), staticOwnerBytes)

            // deploy it
            result := create2(0, code, 75, salt)
        }

        // TODO: quick and dirty debugging of isClone
        // (bool result2, address owner) = isClone(target, result);
        // revert(staticOwner.toString());
        // revert(owner.toString()); // should be 0x57ba9e012762bd38f3a9a2cd1178b5d79b1e266f
        // require(result2, "bad clone");
        // require(owner == staticOwner, "bad owner");
    }

    // TODO: how much cheaper is this than storing all the clone addresses in a mapping of bools?
    function isClone(address target, address query)
        public
        view
        returns (bool result, address owner)
    {
        bytes20 targetBytes = bytes20(target);

        assembly {
            let other := mload(0x40)

            // TODO: right now our contract is 45 bytes + 20 bytes for the owner address, but this will change if we use shorter addresses
            extcodecopy(query, other, 0, 65)

            // load 32 bytes (12 of the bytes will be ignored)
            // the last 20 bytes of this are the owner's address
            owner := mload(add(other, 33))

            let clone := add(other, 65)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), targetBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // we could copy the owner, but theres no real need
            // mstore(add(clone, 0x2d), owner)

            result := and(
                // check bytes 0 through 31
                eq(mload(clone), mload(other)), // check that the first 32 bytes match //and(
                // check bytes 13 through 44
                // we don't care about checking the owner bytes (45 through 65)
                eq(mload(add(clone, 13)), mload(add(other, 13)))
            )
        }
    }
}
