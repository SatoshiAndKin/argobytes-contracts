// SPDX-License-Identifier: MPL-2.0
// this was my original idea, but now i think a bunch of buildings dedicated for each class makes more sense
pragma solidity 0.8.7;

import {RarityPlace} from "./abstract/RarityPlace.sol";

contract GoldMine is RarityPlace {

    constructor(address _cloneFactory) RarityPlace(_cloneFactory) {}

    /// @dev override this to call more during "_summon"
    function _summon_more(uint player, uint summoner, uint class)
        internal override
        returns (uint bonusReward)
    {
        // TODO: set skills, attributes, anything else?
    }


    /// @dev override this to call more during "_work"
    function _work_more(uint player, uint summoner, uint class)
        internal override
        returns (uint bonusReward)
    {
        // TODO: set skills, attributes, anything else?
    }
}
