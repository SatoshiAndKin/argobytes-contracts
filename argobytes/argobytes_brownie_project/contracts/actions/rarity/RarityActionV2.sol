// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {RarityBase} from "contracts/rarity/abstract/RarityBase.sol";

contract RarityActionV2 is RarityBase {

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

    // @dev no auth here. anyone can call adventure for anyone that approves
    function adventure(uint[] calldata summoners) external {
        uint length = summoners.length;
        for (uint i = 0; i < length; i++) {
            RARITY.adventure(summoners[i]);
        }
    }

    // 
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

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        if (interfaceID == 0xffffffff) {
            return false;
        }
        return  interfaceID == 0x01ffc9a7 ||    // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
                interfaceID == 0x80ac58cd;      // ERC-721 support
    }

}
