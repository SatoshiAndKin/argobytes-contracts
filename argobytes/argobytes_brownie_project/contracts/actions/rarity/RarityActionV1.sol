// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {IRarity} from "contracts/external/rarity/IRarity.sol";
import {IRarityGold} from "contracts/external/rarity/IRarityGold.sol";

contract RarityActionV1 {

    IRarity public constant RARITY = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    IRarityGold public constant RARITY_GOLD = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);

    function summonFor(uint class, uint amount, bool with_adventure, address owner) external {
        uint summoner;
        for (uint i = 0; i < amount; i++) {
            summoner = RARITY.next_summoner();
            RARITY.summon(class);
            if (with_adventure) {
                RARITY.adventure(summoner);
            }
            RARITY.safeTransferFrom(address(this), owner, summoner);
        }
    }

    function adventure(uint[] calldata summoners) external {
        uint length = summoners.length;
        for (uint i = 0; i < length; i++) {
            RARITY.adventure(summoners[i]);
        }
    }

    function levelUp(uint[] calldata summoners) external {
        uint length = summoners.length;
        for (uint i = 0; i < length; i++) {
            RARITY.level_up(summoners[i]);
        }
    }

    function claimGold(uint[] calldata summoners) external {
        uint length = summoners.length;
        for (uint i = 0; i < length; i++) {
            RARITY_GOLD.claim(summoners[i]);
        }
    }

    function levelUpAndClaimGold(uint[] calldata summoners) external {
        uint length = summoners.length;
        for (uint i = 0; i < length; i++) {
            RARITY.level_up(summoners[i]);
            RARITY_GOLD.claim(summoners[i]);
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns(bytes4) {
        return this.onERC721Received.selector;
    }
}
