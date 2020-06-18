// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge
*
* Implementation of Diamond facet.
* This is gas optimized by reducing storage reads and storage writes.
*
* In addition to the standard cut function, there are also functions for
* deploying contracts and burning gas token
/******************************************************************************/

import {Create2} from "@openzeppelin/utils/Create2.sol";

import {GasTokenBurner} from "contracts/GasTokenBurner.sol";

import {DiamondStorageContract} from "./DiamondStorageContract.sol";
import {IDiamondCutter} from "./DiamondHeaders.sol";


contract DiamondCutter is DiamondStorageContract, IDiamondCutter, GasTokenBurner {
    bytes32 constant CLEAR_ADDRESS_MASK = 0x0000000000000000000000000000000000000000ffffffffffffffffffffffff;
    bytes32 constant CLEAR_SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    struct SlotInfo {
        uint256 originalSelectorSlotsLength;
        bytes32 selectorSlot;
        uint oldSelectorSlotsIndex;
        uint oldSelectorSlotIndex;
        bytes32 oldSelectorSlot;
        bool newSlot;
    }

    function diamondCut(bytes[] memory _diamondCut) public override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must own the contract.");

        DiamondStorage storage ds = diamondStorage();
        SlotInfo memory slot;
        slot.originalSelectorSlotsLength = ds.selectorSlotsLength;
        uint selectorSlotsLength = uint128(slot.originalSelectorSlotsLength);
        uint selectorSlotLength = uint128(slot.originalSelectorSlotsLength >> 128);
        if(selectorSlotLength > 0) {
            slot.selectorSlot = ds.selectorSlots[selectorSlotsLength];
        }
        // loop through diamond cut
        for(uint diamondCutIndex; diamondCutIndex < _diamondCut.length; diamondCutIndex++) {
            bytes memory facetCut = _diamondCut[diamondCutIndex];
            require(facetCut.length > 20, "Missing facet or selector info.");
            bytes32 currentSlot;
            assembly {
                currentSlot := mload(add(facetCut,32))
            }
            bytes32 newFacet = bytes20(currentSlot);
            uint numSelectors = (facetCut.length - 20) / 4;
            uint position = 52;
            
            // adding or replacing functions
            if(newFacet != 0) {
                // add and replace selectors
                for(uint selectorIndex; selectorIndex < numSelectors; selectorIndex++) {
                    bytes4 selector;
                    assembly {
                        selector := mload(add(facetCut,position))
                    }
                    position += 4;
                    bytes32 oldFacet = ds.facets[selector];
                    // add
                    if(oldFacet == 0) {
                        ds.facets[selector] = newFacet | bytes32(selectorSlotLength) << 64 | bytes32(selectorSlotsLength);
                        slot.selectorSlot = slot.selectorSlot & ~(CLEAR_SELECTOR_MASK >> selectorSlotLength * 32) | bytes32(selector) >> selectorSlotLength * 32;
                        selectorSlotLength++;
                        if(selectorSlotLength == 8) {
                            ds.selectorSlots[selectorSlotsLength] = slot.selectorSlot;
                            slot.selectorSlot = 0;
                            selectorSlotLength = 0;
                            selectorSlotsLength++;
                            slot.newSlot = false;
                        }
                        else {
                            slot.newSlot = true;
                        }
                    }
                    // replace
                    else {
                        require(bytes20(oldFacet) != bytes20(newFacet), "Function cut to same facet.");
                        ds.facets[selector] = oldFacet & CLEAR_ADDRESS_MASK | newFacet;
                    }
                }
            }
            // remove functions
            else {
                for(uint selectorIndex; selectorIndex < numSelectors; selectorIndex++) {
                    bytes4 selector;
                    assembly {
                        selector := mload(add(facetCut,position))
                    }
                    position += 4;
                    bytes32 oldFacet = ds.facets[selector];
                    require(oldFacet != 0, "Function doesn't exist. Can't remove.");
                    if(slot.selectorSlot == 0) {
                        selectorSlotsLength--;
                        slot.selectorSlot = ds.selectorSlots[selectorSlotsLength];
                        selectorSlotLength = 8;
                    }
                    slot.oldSelectorSlotsIndex = uint64(uint(oldFacet));
                    slot.oldSelectorSlotIndex = uint32(uint(oldFacet >> 64));
                    bytes4 lastSelector = bytes4(slot.selectorSlot << (selectorSlotLength-1) * 32);
                    if(slot.oldSelectorSlotsIndex != selectorSlotsLength) {
                        slot.oldSelectorSlot = ds.selectorSlots[slot.oldSelectorSlotsIndex];
                        slot.oldSelectorSlot = slot.oldSelectorSlot & ~(CLEAR_SELECTOR_MASK >> slot.oldSelectorSlotIndex * 32) | bytes32(lastSelector) >> slot.oldSelectorSlotIndex * 32;
                        ds.selectorSlots[slot.oldSelectorSlotsIndex] = slot.oldSelectorSlot;
                        selectorSlotLength--;
                    }
                    else {
                        slot.selectorSlot = slot.selectorSlot & ~(CLEAR_SELECTOR_MASK >> slot.oldSelectorSlotIndex * 32) | bytes32(lastSelector) >> slot.oldSelectorSlotIndex * 32;
                        selectorSlotLength--;
                    }
                    if(selectorSlotLength == 0) {
                        delete ds.selectorSlots[selectorSlotsLength];
                        slot.selectorSlot = 0;
                    }
                    if(lastSelector != selector) {
                        ds.facets[lastSelector] = oldFacet & CLEAR_ADDRESS_MASK | bytes20(ds.facets[lastSelector]);
                    }
                    delete ds.facets[selector];
                }
            }
        }
        uint newSelectorSlotsLength = selectorSlotLength << 128 | selectorSlotsLength;
        if(newSelectorSlotsLength != slot.originalSelectorSlotsLength) {
            ds.selectorSlotsLength = newSelectorSlotsLength;
        }
        if(slot.newSlot) {
            ds.selectorSlots[selectorSlotsLength] = slot.selectorSlot;
        }
        emit DiamondCut(_diamondCut);
    }

    // use CREATE2 to deploy with a salt
    // this function is completely open
    function deploy2(
        bytes32 salt,
        bytes memory initcode
    ) public override payable returns (address deployed) {
        deployed = Create2.deploy(msg.value, salt, initcode);

        // TODO: get rid of this once we figure out why brownie isn't setting return_value
        emit Deploy(deployed);
    }

    // use CREATE2 to deploy with a salt and then free gas tokens
    function deploy2AndBurn(
        address gas_token,
        bytes32 salt,
        bytes memory initcode
    )
        public
        override
        payable
        freeGasTokens(gas_token)
        returns (address deployed)
    {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "ArgobytesOwnedVault.deploy2: Caller is not an admin"
        );

        deployed = Create2.deploy(msg.value, salt, initcode);

        // TODO: get rid of this once we figure out why brownie isn't setting return_value
        emit Deploy(deployed);
    }

    // use CREATE2 to deploy with a salt, cut the diamond, and then free gas tokens
    function deploy2AndCutAndBurn(
        address gas_token,
        bytes32 salt,
        bytes memory facet_initcode,
        bytes memory facet_sigs
    )
        public
        override
        payable
        freeGasTokens(gas_token)
        returns (address deployed)
    {
        // no need for permissions check here since diamondCut does one

        deployed = Create2.deploy(msg.value, salt, facet_initcode);

        bytes[] memory cuts = new bytes[](1);
        cuts[0] = abi.encodePacked(deployed, facet_sigs);

        diamondCut(cuts);

        // TODO: get rid of this once we figure out why brownie isn't setting return_value
        emit Deploy(deployed);
    }
}
