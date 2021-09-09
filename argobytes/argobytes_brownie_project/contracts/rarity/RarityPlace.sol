// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import "@OpenZeppelin/utils/structs/EnumerableSet.sol";

import {RarityOwnable} from "./RarityOwnable.sol";
import {IRarityGold} from "contracts/external/rarity/IRarityGold.sol";

/** @title A place is full of summoners
 */
abstract contract RarityPlace is RarityOwnable {
    using EnumerableSet for EnumerableSet.UintSet;

    IRarityGold public constant RARITY_GOLD = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);
    // TODO: need ability scores so that we will be strong enough to adventure

    // a place can contain other place
    // renown can be exchanged between them
    // only the owner can add new places
    // key is the contract address. value is the exchange rate for renown
    // TODO: what units for exchange rate? 1e9 == 1.0
    // TODO: enumerable map?
    mapping(address => uint) internal places;
    // TODO: owner-only setter
    address surroundingPlace;

    // a place is full of summoners
    EnumerableSet.UintSet internal summoners;
    // TODO: owner-only setter
    uint capacity;
    // TODO: allow buildings to hold multiple classes?
    uint immutable class;
    uint place;

    uint firstAdventureLog;
    uint nextAdventurer;
    uint nextCheck;
    mapping(uint => uint) renown;
    uint totalRenown;

    // TODO: owner-only setter
    uint levelCap;
    // TODO: owner-only setter
    address levelCapDestination;

    event RenownUp(uint indexed player, uint amount);
    event RenownDown(uint indexed player, uint amount);

    // TODO: change this to be a cloneable contract with an initializer
    constructor(
        uint _class,
        uint _levelCap,
        address _surroundingPlace,
        address _levelCapDestination,
        uint _capacity
    ) RarityOwnable(msg.sender) {
        require(_capacity > 0);

        // create a summoner that represents the place
        // as occupants level up and work, they send their gold and such here
        place = RARITY.next_summoner();
        // this does **not** trigger onERC721Received because we are in a constructor
        RARITY.summon(_class);
        // TODO: should the summoner that represents the place "adventure"?
        // TODO: how should we get the gold out and into an AMM?

        class = _class;
        levelCap = _levelCap;
        levelCapDestination = _levelCapDestination;
        capacity = _capacity;
        surroundingPlace = _surroundingPlace;
    }

    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata) external returns(bytes4) {
        require(operator == address(RARITY), "!operator");
        require(summoners.length() < capacity, "full");
        summoners.add(tokenId);
        return this.onERC721Received.selector;
    }

    // TODO: instead of taking ids, cycle using `nextCheck`? have a "startIndex"?
    function checkSummoners(uint player, uint[] memory ids) external {
        uint reward = 0;
        uint length = ids.length;
        for (uint i = 0; i < length; i++) {
            uint summoner = ids[i];

            // if we aren't the owner, we can't manage this
            if (RARITY.ownerOf(summoner) != address(this)) {
                summoners.remove(summoner);
                reward += 1;
                continue;
            }

            // if level above level cap, transfer out
            if (levelCap > 0 && RARITY.level(summoner) > levelCap) {
                RARITY.safeTransferFrom(address(this), levelCapDestination, summoner);
                summoners.remove(summoner);
                reward += 1;
                continue;
            }
        }

        _mintRenown(player, reward);
    }

    function exchangeRenown(uint player, address srcPlace, uint srcAmount) external {
        require(_isApprovedOrOwner(msg.sender, player), "!approve");

        // TODO: variable exchange rates?
        uint exchangeRate = places[srcPlace];

        require(exchangeRate > 0, "!exchangeRate");

        uint destAmount = srcAmount * exchangeRate / 1e9;
        uint roundedSrcAmount = destAmount * 1e9 / exchangeRate;

        RarityPlace(srcPlace).spendRenown(player, roundedSrcAmount);
        _mintRenown(player, destAmount);
    }

    function spendRenown(uint player, uint amount) external {
        require(msg.sender == surroundingPlace);
        renown[player] -= amount;
        totalRenown -= amount;
        emit RenownDown(player, amount);
    }

    function _mintRenown(uint player, uint amount) internal {
        if (amount > 0) {
            renown[player] += amount;
            totalRenown += amount;
            emit RenownUp(player, amount);
        }
    }

    function levelUp(uint player, uint[] memory ids) external returns(uint) {
        uint length = ids.length;
        uint reward = 0;
        for (uint i = 0; i < length; i++) {
            uint summoner = ids[i];

            try RARITY.level_up(summoner) {
                RARITY_GOLD.claim(summoner);

                uint gold = RARITY_GOLD.balanceOf(summoner);

                // todo: the place has gold, but there is no way to get it out. write that!
                RARITY_GOLD.transfer(summoner, place, gold);

                // TODO: how much reward? scale based on gold?
                // TODO: reward the summoner with renown too?
                reward += 1;
            } catch (bytes memory /*lowLevelData*/) {
                // someone must have already leveled this summoner
            }
        }

        _mintRenown(player, reward);
    }

    function _summon() internal {
        RARITY.summon(class);

        _summon_more();
    }

    /// @dev override this to call more during "_summon"
    function _summon_more()
        internal virtual
        returns (uint bonusReward)
    {
        // TODO: set skills, attributes, anything else?
    }

    function summonersLength() public view returns (uint) {
        return summoners.length();
    }

    function work(uint player, uint workNumSummoners) external {
        require(workNumSummoners > 0, "!workNum");

        if (block.timestamp > firstAdventureLog) {
            // the first summoner is able to adventure again
            nextAdventurer = 0;
        }

        uint currentSummoners = summoners.length();

        if (nextAdventurer + workNumSummoners > currentSummoners) {
            // summon more workers
            uint summonersNeeded = nextAdventurer + workNumSummoners - currentSummoners;
            for (uint i = 0; i < summonersNeeded; i++) {
                // this will revert if the place is full
                _summon();
            }
        }

        if (nextAdventurer == 0) {
            firstAdventureLog = block.timestamp;
        }

        // do some sort of adventuring
        uint moreReward = 0;
        for (uint i = 0; i < workNumSummoners; i++) {
            uint summoner = summoners.at(nextAdventurer + i);
            RARITY.adventure(summoner);
            moreReward += _work_more(player, summoner);
        }

        // pay for the work in renown
        _mintRenown(player, workNumSummoners + moreReward);
    }

    /// @dev override this to call any other adventure contracts during "work"
    function _work_more(uint player, uint summoner)
        internal virtual
        returns (uint bonusReward)
    {}

    // TODO: owner-only delegate call/multicall? the owner has approvals for everything
}
