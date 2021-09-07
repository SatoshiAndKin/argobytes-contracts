// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IRarity, IRarityGold} from "contracts/external/rarity/IRarity.sol";

contract RarityActionV1 {

    IRarity public constant RARITY = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    IRarityGold public constant RARITY_GOLD = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);

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
}
