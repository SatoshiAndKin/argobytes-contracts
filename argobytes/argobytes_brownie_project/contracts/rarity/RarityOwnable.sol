// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IRarity} from "contracts/external/rarity/IRarity.sol";

// TODO: typed errors

abstract contract RarityOwnable {
    address private __owner;

    IRarity public constant RARITY = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the passed address as the initial owner.
     */
    constructor(address _owner) {
        _setOwner(_owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return __owner;
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
        _setOwner(address(0));

    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = __owner;

        // TODO: do we want this? it's a bit of a backdoor
        RARITY.setApprovalForAll(oldOwner, false);
        RARITY.setApprovalForAll(newOwner, true);

        __owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // TODO: this probably belongs somewhere else
    function _isApprovedOrOwner(address spender, uint256 summoner) internal view returns (bool) {
        // require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address summoner_owner = RARITY.ownerOf(summoner);
        return (spender == summoner_owner || RARITY.getApproved(summoner) == spender || RARITY.isApprovedForAll(summoner_owner, spender));
    }
}
