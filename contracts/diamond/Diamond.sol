// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Based on https://github.com/mudgen/Diamond By Author: Nick Mudge
/******************************************************************************/

import {IERC165} from "@openzeppelin/introspection/IERC165.sol";

import "./DiamondCutter.sol";
import "./DiamondHeaders.sol";
import "./DiamondLoupe.sol";
import "./DiamondStorageContract.sol";

contract Diamond is DiamondStorageContract, IERC165 {
    // TODO: use OpenZeppelin's access helpers
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(
        address owner,
        bytes32 cutter_salt,
        bytes32 loupe_salt
    ) public payable {
        DiamondStorage storage ds = diamondStorage();
        ds.contractOwner = owner;
        emit OwnershipTransferred(address(0), owner);

        // Create a DiamondCutter contract which implements the IDiamondCutter interface
        // TODO: salt this for CREATE2?
        DiamondCutter diamondCutter = new DiamondCutter{salt: cutter_salt}();

        // Create a DiamondLoupe contract which implements the IDiamondLoupe interface
        // TODO: salt this for CREATE2?
        DiamondLoupe diamondLoupe = new DiamondLoupe{salt: loupe_salt}();

        bytes[] memory diamondCuts = new bytes[](3);

        // Adding cut function
        diamondCuts[0] = abi.encodePacked(
            diamondCutter,
            diamondCutter.diamondCut.selector
        );

        // Adding diamond loupe functions
        diamondCuts[1] = abi.encodePacked(
            diamondLoupe,
            diamondLoupe.facetFunctionSelectors.selector,
            diamondLoupe.facets.selector,
            diamondLoupe.facetAddress.selector,
            diamondLoupe.facetAddresses.selector
        );

        // Adding supportsInterface function
        diamondCuts[2] = abi.encodePacked(
            address(this),
            this.supportsInterface.selector
        );

        // cut the diamond
        bytes memory cutData = abi.encodeWithSelector(
            diamondCutter.diamondCut.selector,
            diamondCuts
        );
        (bool success, ) = address(diamondCutter).delegatecall(cutData);
        require(success, "Adding functions failed.");

        // adding ERC165 data
        ds.supportedInterfaces[this.supportsInterface.selector] = true;
        ds.supportedInterfaces[diamondCutter.diamondCut.selector] = true;
        bytes4 interfaceID = diamondLoupe.facets.selector ^
            diamondLoupe.facetFunctionSelectors.selector ^
            diamondLoupe.facetAddresses.selector ^
            diamondLoupe.facetAddress.selector;
        ds.supportedInterfaces[interfaceID] = true;
    }

    // This implements ERC-165.
    // This is an immutable functions because it is defined directly in the diamond.
    function supportsInterface(bytes4 _interfaceID)
        external
        override
        view
        returns (bool)
    {
        DiamondStorage storage ds = diamondStorage();
        return ds.supportedInterfaces[_interfaceID];
    }

    // Finds facet for function that is called and executes the
    // function if it is found and returns any value.
    fallback() external payable {
        DiamondStorage storage ds = diamondStorage();
        address facet = address(bytes20(ds.facets[msg.sig]));
        require(facet != address(0), "Function does not exist.");
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), facet, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
                case 0 {
                    revert(ptr, size)
                }
                default {
                    return(ptr, size)
                }
        }
    }

    receive() external payable {}
}
