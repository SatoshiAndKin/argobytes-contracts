// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import "@OpenZeppelin/utils/structs/EnumerableSet.sol";
import "@OpenZeppelin/utils/Multicall.sol";

import {CloneFactory} from "contracts/CloneFactory.sol";
import {IRarityAdventure} from "contracts/external/rarity/IRarityAdventure.sol";
import {IRarityGold} from "contracts/external/rarity/IRarityGold.sol";

import {RarityBase} from "./abstract/RarityBase.sol";
import {RarityDice} from "./RarityDice.sol";
import {RarityRenown} from "./RarityRenown.sol";

// TODO: write IRarityPlace.sol

/** @title A place is full of summoners
    // TODO: have some sort of map so places can have coordinates
 */
contract RarityPlace is Multicall, RarityBase {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev a struct full of initial data to avoid "stack too deep" errors
    struct AdventureData {
        address adventure;
        uint reward;
    }

    struct AttributeData {
        uint32 strength;
        uint32 dexterity;
        uint32 constitution;
        uint32 intelligence;
        uint32 wisdom;
        uint32 charisma;
    }

    struct ClassData {
        uint class;
        uint eliteLevel;
        address eliteDestination;
        AttributeData attributes;
        // TODO: skills
    }

    struct InitData {
        AdventureData[] adventures;
        uint baseAdventureReward;
        uint capacity;
        ClassData[] classes;
        uint goldRewardScale; // probably should be 1e18 to match gold
        uint hireCostScale;
        string name;
        address owner;
        uint placeClass;
        uint renownExchangeRate;
        address surroundingPlace;
        uint workBaseReward; // probably should be 250e18 to match xp
        uint16 workTaxBps; // max of 10,000
    }

    struct PlaceClassData {
        AttributeData attributes;
        // TODO: randomized skills
    }

    struct NewPlaceData {
        // by default, we clone the parent. but any contract can be cloned (so long as is IRarityPlace)
        RarityPlace implContract;
        // TODO: rename "salt" to "location" and use it as coordinates somehow?
        bytes32 salt;
        AdventureData[] adventures;
        uint baseAdventureReward;
        uint capacity;
        ClassData[] classes;
        uint eliteLevel;
        uint goldRewardScale;
        string name;
        uint placeClass;
        PlaceClassData placeClassData;
        uint ourRenownExchangeRate;
        uint theirRenownExchangeRate;
        uint16 workTaxBps;
    }


    /// @dev a place is full of adventures
    // TODO: owner-only setter
    EnumerableSet.AddressSet internal adventures;
    /// @dev each adventure gives renown. 1e18 == 1.0
    mapping(address => uint) public adventureRewardScale;

    /// @dev the base renown given for calling `work`
    uint baseAdventureReward;

    /// @dev a place has limited capacity
    uint capacity;
    /// @dev a place can limit its classes. it can do ratios too by doing `[barb, barb, fighter]`
    ClassData[] classes;

    /// @dev roll some dice
    RarityDice immutable dice;

    /// @dev track the timestamp that the first npc in summoners last adventured
    uint firstSummonerAdventureLog;

    // 1e18 == 1.0
    uint goldRewardScale;

    // 1e18 == 1.0
    uint hireCostScale;

    // TODO: owner-only setter for eliteLevel and eliteLevelDestinations that makes sure all classes get set
    /// @dev once a summmoner levels up past the eliteLevel, they can move to eliteLevelDestination
    uint eliteLevel;
    /// @dev an address for the summoners to move to. Probably a Mercenary Camp
    address[11] eliteLevelDestinations;

    /// @dev a place must have a name
    string name;

    /// @dev the next summoner that is ready for adventure. if > summoners.lenght, summon more
    /// TODO: helper function to reset this in case of some bug? worst case its stuck for a day
    uint nextSummoner;

    /// @dev The owner of this contract. VERY POWERFUL!
    // TODO: owner ownly setter
    address public owner;

    /** @dev
        a place can contain other place
        renown can be exchanged between them
        only the owner can add new places
        key is the contract address. value is the exchange rate for renown
        // TODO: what units for exchange rate? 1e18 == 1.0
        // TODO: owner-only setter
    */
    EnumerableSet.AddressSet internal places;

    /// @dev a place has a primary summoner for holding pooled funds
    uint placeSummoner;

    /// @dev contract for managing renown
    RarityRenown public immutable renown;

    /// @dev a place is full of NPC summoners
    EnumerableSet.UintSet internal summoners;

    /// @dev summoners that have done their work and hit the level cap
    EnumerableSet.UintSet[11] internal eliteSummoners;

    // 1e18 == 1.0
    uint public summonerReward;

    /// @dev the place that this place is inside. this place can spend our renown
    // TODO: owner-only setter
    RarityPlace public surroundingPlace;

    /// @dev tax taken out of work
    uint16 public workTaxBps;

    // non-game data
    /// @dev A contract used to clone this contract
    CloneFactory private immutable cloneFactory;
    /// @dev This contract has been initialized
    bool private initialized;
    /// @dev The original address of this contract
    address private immutable original;

    ///
    /// Contract setup functions
    ///

    /// @notice a mostly empty constructor. use createNewPlace to actually make a place.
    constructor(CloneFactory _cloneFactory, RarityDice _dice, RarityRenown _renown) {
        // game immutables
        dice = _dice;
        renown = _renown;

        // non-game immutables
        cloneFactory = _cloneFactory;
        // save this address in the bytecode so that we can check for delegatecalls
        original = address(this);
    }

    /// @notice setup state on a clone. call via newPlace
    function initialize(InitData calldata initData) external {
        // security checks
        require(address(this) != original, "!delegatecall");

        if (initialized) {
            // we allow calling init again, but only by the owner
            require(!initialized, "!initialize");
        }

        initialized = true;

        uint l = initData.adventures.length;
        for (uint i = 0; i < l; i++) {
            address adventure = initData.adventures[i].adventure;
            adventures.add(adventure);
            adventureRewardScale[adventure] = initData.adventures[i].reward;
        }

        baseAdventureReward = initData.baseAdventureReward;
        capacity = initData.capacity;

        l = initData.classes.length;
        for (uint i = 0; i < l; i++) {
            classes[i] = initData.classes[i];
        }

        goldRewardScale = initData.goldRewardScale;
        name = initData.name;
        owner = initData.owner;

        renown.setExchangeRate(initData.surroundingPlace, initData.renownExchangeRate);

        surroundingPlace = RarityPlace(initData.surroundingPlace);
        workTaxBps = initData.workTaxBps;

        // create a summoner that represents the place
        // as occupants level up and work, they send their gold and such here
        // the onReceive hook sets placeSummoner to the tokenId
        if (placeSummoner == 0) {
            RARITY.summon(initData.placeClass);
        }
        // TODO: should the summoner that represents the place "adventure"? have stats?
        // TODO: how should we get the gold out and into an AMM?
        // TODO: how should we get materials out of the extra adventures?
    }

    /// @notice create a clone of this contract
    function newPlace(NewPlaceData calldata newPlaceData) external returns(RarityPlace) {
        InitData memory initData;

        initData.adventures = newPlaceData.adventures;
        initData.baseAdventureReward = newPlaceData.baseAdventureReward;
        initData.capacity = newPlaceData.capacity;
        initData.classes = newPlaceData.classes;
        initData.name = newPlaceData.name;
        initData.placeClass = newPlaceData.placeClass;
        initData.renownExchangeRate = newPlaceData.theirRenownExchangeRate;
        initData.workTaxBps = newPlaceData.workTaxBps;

        if (address(this) == original) {
            // if called on the original contract, create a new place not inside any other
            require(newPlaceData.ourRenownExchangeRate == 0, "!_ourRenownExchangeRate");
            require(newPlaceData.theirRenownExchangeRate == 0, "!_theirRenownExchangeRate");
            initData.owner = msg.sender;
            // initData.surroundingPlace = address(0);
        } else {
            // if called on a clone, create a new place inside the clone
            require(owner == msg.sender, "!owner");
            initData.owner = owner;
            initData.surroundingPlace = address(this);
        }

        // ensure different initializers get different addresses
        bytes32 salt = keccak256(abi.encode(newPlaceData.salt, initData));

        // allow cloning any contract, not just this one
        address place;
        if (address(newPlaceData.implContract) == address(0)) {
            place = cloneFactory.cloneTarget(address(this), salt);
        } else {
            place = cloneFactory.cloneTarget(address(newPlaceData.implContract), salt);
        }

        if (initData.surroundingPlace == address(this)) {
            _surroundPlace(place, newPlaceData.ourRenownExchangeRate);
        } else {
            // if surrounding place isn't this place, we can't use ourRenownExchangeRate
            require(newPlaceData.ourRenownExchangeRate == 0, "!ourRenownExchangeRate");
        }

        RarityPlace(place).initialize(initData);

        return RarityPlace(place);
    }
    
    ///
    /// Place management functions
    ///

    /// @dev join this place to a different surroundingPlace. call this before surroundPlace
    function joinPlace(address _newSurroundingPlace, uint _renownExchangeRate) external {
        require(owner == msg.sender, "!owner");
        surroundingPlace = RarityPlace(_newSurroundingPlace);

        renown.setExchangeRate(_newSurroundingPlace, _renownExchangeRate);

        // TODO: event?
    }

    /// @notice Add a place to this place (owner-only). call this after joinPlace
    function surroundPlace(address _place, uint _renownExchangeRate) external {
        require(owner == msg.sender, "!owner");
        _surroundPlace(_place, _renownExchangeRate);
    }

    function _surroundPlace(address _place, uint _renownExchangeRate) internal {
        require(RarityPlace(_place).surroundingPlace() == this, "!surrounding");

        places.add(_place);

        renown.setExchangeRate(_place, _renownExchangeRate);

        // TODO: event?
    }

    /// @notice Remove a place from this place (owner-only)
    function removePlace(address _place) external {
        require(owner == msg.sender, "!owner");
        require(RarityPlace(_place).surroundingPlace() != this, "!surrounding");

        places.remove(_place);

        // TODO: always clear exchange rate?
        renown.setExchangeRate(_place, 0);

        // TODO: event?
    }

    ///
    /// Summoner management functions
    ///

    // TODO: make sure this stays under 30k gas!
    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata) external returns(bytes4) {
        require(RARITY.ownerOf(tokenId) == address(this), "wtf");

        uint class = RARITY.class(tokenId);
        uint classesLength = classes.length;

        bool classValid = false;
        for (uint i = 0; i < classesLength; i++) {
            if (classes[i].class == class) {
                classValid = true;
                break;
            }
        }

        if (placeSummoner == 0) {
            placeSummoner = tokenId;
        } else {
            require(summoners.length() < capacity, "full");
            summoners.add(tokenId);
        }
        return this.onERC721Received.selector;
    }

    function _levelUp(uint summoner) internal returns(uint) {
        uint reward = 0;

        try RARITY.level_up(summoner) {
            uint gold_claimed = RARITY_GOLD.claimable(summoner);

            if (gold_claimed > 0) {
                RARITY_GOLD.claim(summoner);

                // todo: the place has gold, but there is no way to get it out. write that!
                RARITY_GOLD.transfer(summoner, placeSummoner, gold_claimed * workTaxBps / 10000);

                // RARITY_GOLD.decimals() == 18
                reward += gold_claimed * goldRewardScale / 1e18;
            }
        } catch (bytes memory /*lowLevelData*/) {
            // the summoner is not ready to lvle up
        }

        return reward;
    }

    /// @dev summon a summoner for this placae
    function _summon(uint player) internal {
        uint class = classes[summoners.length() % classes.length].class;
        uint summoner = RARITY.next_summoner();

        RARITY.summon(class);

        uint reward = 1e18 * summonerReward / 1e18;

        renown.mint(summoner, summonerReward);
        renown.mint(player, summonerReward);

        _summon_more(player, summoner);
    }

    /// @dev override this to call more during "_summon"
    function _summon_more(uint player, uint summoner)
        internal virtual
        returns (uint bonusReward)
    {
        // TODO: set skills, attributes, anything else?
    }

    /// @notice the number of summoners in this place
    function summonersLength() public view returns (uint) {
        return summoners.length();
    }

    /// @notice Tell summoners at this place to do some work. Rewards renown to the player.
    function work(uint player, uint workNumSummoners) external {
        require(workNumSummoners > 0, "!workNum");

        if (block.timestamp > firstSummonerAdventureLog) {
            // the first summoner is able to adventure again
            nextSummoner = 0;
        }
        if (nextSummoner == 0) {
            firstSummonerAdventureLog = block.timestamp;
        }

        uint currentSummoners = summoners.length();

        if (nextSummoner + workNumSummoners > currentSummoners) {
            // summon more workers
            uint summonersNeeded = nextSummoner + workNumSummoners - currentSummoners;
            for (uint i = 0; i < summonersNeeded; i++) {
                // this will revert if the place is full
                _summon(player);
            }
        }

        // do some adventuring (and maybe more)
        uint reward = 0;
        uint moreAdventures = adventures.length();
        for (uint i = 0; i < workNumSummoners; i++) {
            uint summoner = summoners.at(nextSummoner + i);

            // base adventure
            uint thisReward = baseAdventureReward;
            RARITY.adventure(summoner);

            // try to level up
            thisReward += _levelUp(summoner);

            // more adventures
            for (uint j = 0; j < moreAdventures; j++) {
                IRarityAdventure adventure = IRarityAdventure(adventures.at(j));
                if (adventure.scout(summoner) > 0) {
                    uint rewardScale = adventureRewardScale[address(adventure)];

                    uint claimed = adventure.adventure(summoner);

                    // we could take a percentage of claimed, but they are small ints so rounding means we usually get 0
                    // so instead, the placeSummoner has a chance to take all of what is claimed
                    // this should add some randomness to the NPCs
                    if (dice.random(summoner) % 10000 <= workTaxBps) {
                        adventure.transfer(summoner, placeSummoner, claimed);
                    }

                    // unlike gold and xp, claimed items have 0 decimals
                    // multiply by 1e18 to fractionalize the claimed items
                    thisReward += claimed * 1e18 * rewardScale / 1e18;
                }
            }

            thisReward += _work_more(player, summoner);

            // give renown to the summoner. we will use this to calculate their cost to hire
            renown.mint(summoner, thisReward);

            // keep counting for the reward for the player
            reward += thisReward;
        }

        // pay for the work in renown
        renown.mint(player, reward);
    }

    /// @dev override this to call any other adventure contracts during "work"
    function _work_more(uint player, uint summoner)
        internal virtual
        returns (uint bonusReward)
    {
        // do something cool
    }

    function setCapacity(uint _capacity)
        external
    {
        capacity = _capacity;

        if (summoners.length() < _capacity) {
            return;
        }

        revert("todo: move extra summoners out. reset nextSummoner");
    }

    function hireSummoner(uint _summoner, uint _renownIn, uint class, address newOwner) external {
        _hireSummoner(_summoner, _renownIn, class, newOwner, summoners);
    }

    function hireEliteSummoner(uint _summoner, uint _renownIn, uint class, address newOwner) external {
        _hireSummoner(_summoner, _renownIn, class, newOwner, eliteSummoners[class]);
    }

    function _hireSummoner(uint _summoner, uint _renownIn, uint class, address newOwner, EnumerableSet.UintSet storage _summoners) internal {
        // TODO: don't just hire the first summoner. find one that can be purchased for this much renownIn
        uint hired = _summoners.at(0);

        uint hiredRenownBalance = renown.balanceOf(address(this), hired);

        // TODO: better price depending on _summoner's skills/level?
        uint cost = hiredRenownBalance * hireCostScale / 1e18;

        renown.burn(_summoner, cost);
        renown.burn(hired, hiredRenownBalance);

        _summoners.remove(hired);

        RARITY.safeTransferFrom(address(this), newOwner, hired);
    }

    ///
    /// Administration functions
    ///

    /** @dev TODO
    
        setOwner
        setCapacity
        setClasses (and eliteLevel and Destinations)
        setName
        transferOwnership    
        takeOwnership
        revokeOwnership
    
     */

    // TODO: write the rest of this setter
    /*
    function _setOwner(address newOwner) private {
        address oldOwner = __owner;

        // TODO: do we want this? it's a bit of a backdoor
        RARITY.setApprovalForAll(oldOwner, false);
        RARITY.setApprovalForAll(newOwner, true);

        __owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }
    */

    // TODO: owner-only delegate call/multicall? the owner has approvals for everything
}
