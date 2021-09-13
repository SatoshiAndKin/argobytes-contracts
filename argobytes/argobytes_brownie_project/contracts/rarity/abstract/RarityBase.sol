// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IRarity} from "contracts/external/rarity/IRarity.sol";
import {IRarityAttributes} from "contracts/external/rarity/IRarityAttributes.sol";
import {IRarityGold} from "contracts/external/rarity/IRarityGold.sol";
import {IRaritySkills} from "contracts/external/rarity/IRaritySkills.sol";

abstract contract RarityBase {

    IRarity public constant RARITY = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    IRarityGold public constant RARITY_GOLD = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);
    IRarityAttributes public constant RARITY_ATTRIBUTES = IRarityAttributes();
    IRaritySkills public constant RARITY_SKILLS = IRaritySkills();
    // TODO: what else?

    function _isApprovedOrOwner(address spender, uint256 summoner) internal view returns (bool) {
        // require(_exists(summoner), "ERC721: operator query for nonexistent token");
        address summoner_owner = RARITY.ownerOf(summoner);
        return (spender == summoner_owner || RARITY.getApproved(summoner) == spender || RARITY.isApprovedForAll(summoner_owner, spender));
    }

    modifier auth(uint summoner) {
        require(_isApprovedOrOwner(msg.sender, summoner), "!auth");
        _;
    }
}
