// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IRarity} from "contracts/external/rarity/IRarity.sol";
import {RarityBase} from "./RarityBase.sol";

// TODO: typed errors

/// @title a contract that is owned by its 
abstract contract RarityOwnable is RarityBase {
    uint private __owner;

    event OwnershipTransferred(uint indexed previousOwner, uint indexed newOwner);

    /**
     * @dev Initializes the contract setting the passed address as the initial owner.
     */
    constructor(uint _owner) {
        _setOwner(_owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return RARITY.ownerOf(__owner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "!owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(uint newOwner) public virtual onlyOwner {
        require(newOwner != 0, "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(uint newOwner) private {
        uint oldOwner = __owner;

        __owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

}
