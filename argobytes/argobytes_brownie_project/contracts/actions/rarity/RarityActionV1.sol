// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IRarity, IRarityGold} from "contracts/external/rarity/IRarity.sol";

contract RarityActionV1 {

    IRarity public constant RARITY = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    IRarityGold public constant RARITY_GOLD = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);

    function summonAndAdventure(uint[11] calldata summonedPerClass, address owner) external {
        uint summoner;
        for (uint class_id = 0; class_id < 11; class_id++) {
            for (uint i = 0; i < summonedPerClass[class_id]; i++) {
                summoner = RARITY.next_summoner();
                RARITY.summon(class_id + 1);
                RARITY.adventure(summoner);
                RARITY.safeTransferFrom(address(this), owner, summoner);
            }
        }
    }

    function adventure(uint[] calldata adventurers) external {
        uint length = adventurers.length;
        for (uint i = 0; i < length; i++) {
            RARITY.adventure(adventurers[i]);
        }
    }

    function levelUp(uint[] calldata adventurers) external {
        uint length = adventurers.length;
        for (uint i = 0; i < length; i++) {
            RARITY.level_up(adventurers[i]);
        }
    }

    function levelUpAndClaim(uint[] calldata adventurers) external {
        uint length = adventurers.length;
        for (uint i = 0; i < length; i++) {
            RARITY.level_up(adventurers[i]);
            RARITY_GOLD.claim(adventurers[i]);
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns(bytes4) {
        return this.onERC721Received.selector;
    }
}
