// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import {RarityBase} from "./abstract/RarityBase.sol";

interface IRarityCrafting {
    function simulate(uint _summoner, uint _base_type, uint _item_type, uint _crafting_materials) external view returns (bool crafted, int check, uint cost, uint dc);
}


// TODO: shhould this be a rarityplace or a adventure? if adventure, we need to setup multiple approvals. unless we change our adventuring to always use delegatecall wrappers
contract RarityWorkshop1 is RarityPlace, IRarityAdventure {

    CRAFTING_I = IRarityCrafting(0xf41270836dF4Db1D28F7fd0935270e3A603e78cC);

    function _summon_more(uint player, uint summoner) {
        // TODO: assign attributes
        RARITY_ATTRIBUTES = 
    }

    function _work_more(uint player, uint summoner)
        internal virtual
        returns (uint bonusReward)
    {
        (bool crafted, int check, uint cost, uint dc) = CRAFTING_I.simulate(_summoner, );

        if (reward) {
            // TODO: transfer `cost` gold from summonerPlace to summoner?
            // TODO: transfer `cost` gold from player?
            
            try CRAFTING_I.craft(_summoner) {

            }
        }


        _mint(_summoner, reward);
    }

    function scout(uint summoner) {

    }
}
