// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge
*
* Implementation of an example of a diamond.
/******************************************************************************/

import {AccessControl} from "@OpenZeppelin/access/AccessControl.sol";
import {IERC165} from "@OpenZeppelin/introspection/IERC165.sol";

import "./libraries/LibDiamondStorage.sol";
import "./libraries/LibDiamond.sol";
import "./facets/DiamondFacet.sol";

// TODO: fork AccessControl to use DiamondStorage

contract Diamond is AccessControl {

    constructor(address admin, address facet) payable {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();

        // grant admin role
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        // Create a DiamondFacet contract which implements the Diamond interface
        // TODO: will using an interface for this save any gas?
        DiamondFacet diamondFacet = DiamondFacet(facet);
        
        bytes[] memory cut = new bytes[](1);
        
        // Adding diamond functions
        cut[0] = abi.encodePacked(
            diamondFacet,
            DiamondFacet.deploy2AndFree.selector,
            DiamondFacet.deploy2AndDiamondCutAndFree.selector,
            DiamondFacet.diamondCut.selector,
            DiamondFacet.diamondCutAndFree.selector,
            DiamondFacet.facetFunctionSelectors.selector,
            DiamondFacet.facets.selector,
            DiamondFacet.facetAddress.selector,
            DiamondFacet.facetAddresses.selector,
            DiamondFacet.supportsInterface.selector
        );

        // execute non-standard internal diamondCut function to add functions
        LibDiamond.diamondCut(cut);
        
        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamondStorage.DiamondStorage storage ds;
        bytes32 position = LibDiamondStorage.DIAMOND_STORAGE_POSITION;
        assembly { ds.slot := position }
        address facet = address(bytes20(ds.facets[msg.sig]));  
        require(facet != address(0));      
        assembly {            
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)            
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {revert(0, returndatasize())}
            default {return (0, returndatasize())}
        }
    }

    receive() external payable {}   
}
