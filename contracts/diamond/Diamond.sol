// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Based on https://github.com/mudgen/Diamond By Author: Nick Mudge
/******************************************************************************/

import {IERC165} from "@OpenZeppelin/introspection/IERC165.sol";

import "./DiamondCutter.sol";
import "./DiamondHeaders.sol";
import "./DiamondLoupe.sol";
import "./DiamondStorageContract.sol";

contract Diamond is DiamondStorageContract, IERC165 {
    constructor(address cutter, address loupe) payable {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        DiamondStorage storage ds = diamondStorage();

        // Use an already deployed DiamondCutter contract
        IDiamondCutter diamondCutter = IDiamondCutter(cutter);

        // Use an already deployed DiamondLoupe contract
        IDiamondLoupe diamondLoupe = IDiamondLoupe(loupe);

        bytes[] memory diamondCuts = new bytes[](3);

        // Adding diamond cutter functions
        diamondCuts[0] = abi.encodePacked(
            diamondCutter,
            diamondCutter.diamondCut.selector,
            // TODO: do we actually want deploy2+deploy2AndFree? That's available on the lgt contracts
            diamondCutter.deploy2.selector,
            diamondCutter.deploy2AndFree.selector,
            diamondCutter.deploy2AndCutAndFree.selector
        );

        // Adding diamond loupe functions
        diamondCuts[1] = abi.encodePacked(
            diamondLoupe,
            diamondLoupe.facetAddress.selector,
            diamondLoupe.facetAddresses.selector,
            diamondLoupe.facetFunctionSelectors.selector,
            diamondLoupe.facets.selector
        );

        // Adding supportsInterface function
        diamondCuts[2] = abi.encodePacked(
            address(this),
            this.supportsInterface.selector
        );

        // cut the diamond
        // since this uses delegate call, msg.sender (which is used for auth) is unchanged
        bytes memory cutData = abi.encodeWithSelector(
            diamondCutter.diamondCut.selector,
            diamondCuts
        );
        (bool success, ) = address(diamondCutter).delegatecall(cutData);
        require(success, "Adding functions failed.");

        // add ERC165 data
        ds.supportedInterfaces[this.supportsInterface.selector] = true;

        // add ERC165 data for diamondCutter
        bytes4 interfaceID = diamondCutter.diamondCut.selector ^
            diamondCutter.deploy2.selector ^
            diamondCutter.deploy2AndCut.selector ^
            diamondCutter.deploy2AndFree.selector ^
            diamondCutter.deploy2AndCutAndFree.selector;

        ds.supportedInterfaces[interfaceID] = true;

        // add ERC165 data for diamondLoupe
        interfaceID =
            diamondLoupe.facetFunctionSelectors.selector ^
            diamondLoupe.facetAddresses.selector ^
            diamondLoupe.facetAddress.selector ^
            diamondLoupe.facets.selector;

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
