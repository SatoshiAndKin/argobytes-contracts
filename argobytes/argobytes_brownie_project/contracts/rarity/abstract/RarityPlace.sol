// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.7;

import "@OpenZeppelin/utils/structs/EnumerableSet.sol";
import "@OpenZeppelin/utils/Multicall.sol";

import {CloneFactory} from "contracts/CloneFactory.sol";
import {RarityCommon} from "./RarityCommon.sol";
import {IRarityAdventure} from "contracts/external/rarity/IRarityAdventure.sol";
import {IRarityGold} from "contracts/external/rarity/IRarityGold.sol";


/** @title A place is full of summoners
    // TODO: have some sort of map so places can have coordinates
 */
abstract contract RarityPlace is Multicall, RarityCommon {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IRarityGold public constant RARITY_GOLD = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);

    /// @dev a place is full of adventures
    // TODO: owner-only setter
    EnumerableSet.AddressSet internal adventures;

    /// @dev a place has limited capacity
    // TODO: owner-only setter
    uint capacity;
    /// @dev a place can limit its classses
    // TODO: owner-only setter
    uint[] classes;
    // TODO: need ability scores/class so that we will be strong enough to adventure

    /// @dev a place has a primary summoner for holding pooled funds
    uint placeSummoner;

    /// @dev track the timestamp that the first npc in summoners last adventured
    uint firstSummonerAdventureLog;

    /// @dev a place must have a name
    string name;

    /// @dev the next summoner that is ready for adventure. if > summoners.lenght, summon more
    uint nextSummoner;
    /// @dev the next summoner that is ready to be checked for level or loot
    uint nextSummonerToCheck;

    /** @dev
        a place can contain other place
        renown can be exchanged between them
        only the owner can add new places
        key is the contract address. value is the exchange rate for renown
        // TODO: what units for exchange rate? 1e9 == 1.0
        // TODO: owner-only setter
    */
    EnumerableSet.AddressSet internal places;

    /// @dev mapping to get information about the places inside this place
    mapping(address => uint) internal renownExchangeRate;

    /// @dev a place is full of NPC summoners
    EnumerableSet.UintSet internal summoners;

    /// @dev the place that this place is inside. this place can spend our renown
    // TODO: owner-only setter
    RarityPlace public surroundingPlace;

    /// @dev tracking how often an outsider has led an adventure at this place
    mapping(uint => uint) public renownOf;
    /// @dev the total unspent renown
    uint public totalRenown;

    event RenownUp(uint indexed player, uint amount);
    event RenownDown(uint indexed player, uint amount);

    // TODO: owner-only setter for levelCap and levelCapDestinations that makes sure all classes get set
    /// @dev once a summmoner levels up past the levelCap, they can move to levelCapDestination
    uint levelCap;
    /// @dev an address for the summoners to move to. Probably a Mercenary Camp
    address[11] levelCapDestinations;

    /// @dev The owner of this contract. VERY POWERFUL!
    // TODO: owner ownly setter
    address private owner;

    // non-game state
    /// @dev The original address of this contract
    address private immutable original;
    /// @dev A contract used to clone this contract
    CloneFactory private immutable cloneFactory;

    ///
    /// Contract setup functions
    ///

    /// @notice a mostly empty constructor. use createNewPlace to actually make a place.
    constructor(address _cloneFactory) {
        // save this address in the bytecode so that we can check for delegatecalls
        original = address(this);
        cloneFactory = CloneFactory(_cloneFactory);
    }

    /// @dev a struct full of initial data to avoid "stack too deep" errors
    struct InitData {
        address[] adventures;
        uint256 capacity;
        uint256[] classes;
        uint256 levelCap;
        address[11] levelCapDestinations;
        string name;
        address owner;
        uint256 placeClass;
        address surroundingPlace;
    }

    /// @notice setup state on a clone. call via newPlace
    function initialize(bytes calldata encodedInitData) external {
        // security checks
        require(address(this) != original, "!delegatecall");
        require(msg.sender == address(cloneFactory), "!cloneFactory");

        InitData memory initData = abi.decode(encodedInitData, (InitData));

        uint adventuresLength = initData.adventures.length;
        for (uint i = 0; i < adventuresLength; i++) {
            adventures.add(initData.adventures[i]);
        }

        capacity = initData.capacity;
        classes = initData.classes;
        levelCap = initData.levelCap;
        levelCapDestinations = initData.levelCapDestinations;
        name = initData.name;
        owner = initData.owner;
        surroundingPlace = RarityPlace(initData.surroundingPlace);

        // create a summoner that represents the place
        // as occupants level up and work, they send their gold and such here
        placeSummoner = RARITY.next_summoner();
        // this does **not** trigger onERC721Received because we are in a constructor
        RARITY.summon(initData.placeClass);
        // TODO: should the summoner that represents the place "adventure"? have stats?
        // TODO: how should we get the gold out and into an AMM?
    }

    /// @notice create a clone of this contract
    function newPlace(
        address[] calldata _adventures,
        uint _capacity,
        uint[] calldata _classes,
        uint _levelCap,
        address[11] calldata _levelCapDestinations,
        string calldata _name,
        uint _placeClass,
        uint _renownExchangeRate,
        bytes32 _salt
    ) external returns(address) {
        InitData memory initData;

        initData.adventures = _adventures;
        initData.capacity = _capacity;
        initData.classes = _classes;
        initData.levelCap = _levelCap;
        initData.levelCapDestinations = _levelCapDestinations;
        initData.name = _name;
        initData.placeClass = _placeClass;

        if (address(this) == original) {
            // if called on the original contract, create a new place not inside any other
            require(_renownExchangeRate == 0, "!_renownExchangeRate");
            initData.owner = msg.sender;
            // initData.surroundingPlace = address(0);
        } else {
            // if called on a clone, create a new place inside the clone
            require(owner == msg.sender, "!owner");
            initData.owner = owner;
            initData.surroundingPlace = address(this);
        }

        bytes memory encodedInitData = abi.encode(initData);

        address place = cloneFactory.cloneAndInit(address(this), _salt, encodedInitData);

        if (initData.surroundingPlace == address(this)) {
            places.add(place);
            renownExchangeRate[place] = _renownExchangeRate;
        }

        return place;
    }
    
    ///
    /// Place management functions
    ///

    /// @dev join this place to a different surroundingPlace
    function joinPlace(address place, address _newSurroundingPlace) external {
        require(owner == msg.sender, "!owner");
        surroundingPlace = RarityPlace(_newSurroundingPlace);
        // TODO: event?
    }

    /// @notice Add a place to this place (owner-only)
    function surroundPlace(address place, uint _renownExchangeRate) external {
        require(owner == msg.sender, "!owner");
        require(RarityPlace(place).surroundingPlace() == this, "!surrounding");

        places.add(place);
        renownExchangeRate[place] = _renownExchangeRate;

        // TODO: event?
    }

    /// @notice Remove a place from this place (owner-only)
    function removePlace(address place) external {
        require(owner == msg.sender, "!owner");
        require(RarityPlace(place).surroundingPlace() != this, "!surrounding");

        places.remove(place);
        delete renownExchangeRate[place];

        // TODO: event?
    }

    ///
    /// Summoner management functions
    ///

    // TODO: make sure this stays under 30k gas!
    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata) external returns(bytes4) {
        require(operator == address(RARITY), "!operator");
        require(summoners.length() < capacity, "full");

        uint class = RARITY.class(tokenId);
        uint classesLength = classes.length;

        bool classValid = false;
        for (uint i = 0; i < classesLength; i++) {
            if (classes[i] == class) {
                classValid = true;
                break;
            }
        }

        summoners.add(tokenId);
        return this.onERC721Received.selector;
    }

    // TODO: instead of taking ids, cycle using `nextSummonerToCheck`? have a "startIndex"?
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
                // TODO: get level and class in one call
                uint levelCapDestinationIndex = RARITY.class(summoner) - 1;

                RARITY.safeTransferFrom(address(this), levelCapDestinations[levelCapDestinationIndex], summoner);
                summoners.remove(summoner);
                reward += 1;
                continue;
            }
        }

        _mintRenown(player, reward);
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
                RARITY_GOLD.transfer(summoner, placeSummoner, gold);

                // TODO: how much reward? scale based on gold?
                // TODO: reward the summoner with renown too?
                reward += 1;
            } catch (bytes memory /*lowLevelData*/) {
                // someone must have already leveled this summoner
            }
        }

        _mintRenown(player, reward);
    }

    /// @dev summon a summoner for this placae
    function _summon(uint player) internal {
        uint class = classes[summoners.length() % classes.length];
        uint summoner = RARITY.next_summoner();

        RARITY.summon(class);

        _summon_more(player, summoner, class);
    }

    /// @dev override this to call more during "_summon"
    function _summon_more(uint player, uint summoner, uint class)
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

        uint currentSummoners = summoners.length();

        if (nextSummoner + workNumSummoners > currentSummoners) {
            // summon more workers
            uint summonersNeeded = nextSummoner + workNumSummoners - currentSummoners;
            for (uint i = 0; i < summonersNeeded; i++) {
                // this will revert if the place is full
                _summon(player);
            }
        }

        if (nextSummoner == 0) {
            firstSummonerAdventureLog = block.timestamp;
        }

        // do some sort of adventuring
        uint moreReward = 0;
        uint moreAdventures = adventures.length();
        for (uint i = 0; i < workNumSummoners; i++) {
            uint summoner = summoners.at(nextSummoner + i);
            RARITY.adventure(summoner);

            uint class = RARITY.class(summoner);

            for (uint j = 0; j < moreAdventures; j++) {
                // TODO: is scouting on chain too gas expensive? put this in a try block instead?
                // TODO: will everything have a scout method?
                IRarityAdventure adventure = IRarityAdventure(adventures.at(j));
                if (adventure.scout(summoner) > 0) {
                    moreReward += adventure.adventure(summoner);
                }
            }

            moreReward += _work_more(player, summoner, class);
        }

        // pay for the work in renown
        _mintRenown(player, workNumSummoners + moreReward);
    }

    /// @dev override this to call any other adventure contracts during "work"
    function _work_more(uint player, uint summoner, uint class)
        internal virtual
        returns (uint bonusReward)
    {
        // do something cool
    }

    ///
    /// Renown functions
    ///

    function exchangeRenown(uint player, address srcPlace, uint srcAmount, address dstPlace) internal returns (uint) {
        require(_isApprovedOrOwner(msg.sender, player), "!approve");
        return _exchangeRenown(player, srcPlace, srcAmount, dstPlace);
    }

    function _exchangeRenown(uint player, address srcPlace, uint srcAmount, address dstPlace) internal returns (uint) {
        if (srcPlace == address(this)) {
            require(places.contains(dstPlace), "!dstPlace");

            // TODO: variable exchange rates?
            uint exchangeRate = renownExchangeRate[srcPlace];

            require(exchangeRate > 0, "!exchangeRate");

            // TODO: double check and document this math
            uint destAmount = srcAmount / exchangeRate * 1e9;
            uint roundedSrcAmount = destAmount / 1e9 * exchangeRate;

            _spendRenown(player, roundedSrcAmount);
            RarityPlace(dstPlace).mintRenown(player, destAmount);

            return destAmount;
        }
        
        if (dstPlace == address(this)) {
            require(places.contains(srcPlace), "!srcPlace");

            // TODO: variable exchange rates?
            uint exchangeRate = renownExchangeRate[srcPlace];

            require(exchangeRate > 0, "!exchangeRate");

            // TODO: double check and document this math
            uint destAmount = srcAmount * exchangeRate / 1e9;
            uint roundedSrcAmount = destAmount * 1e9 / exchangeRate;

            RarityPlace(srcPlace).spendRenown(player, roundedSrcAmount);
            _mintRenown(player, destAmount);

            return destAmount;
        }

        // place to place trade
        require(places.contains(srcPlace), "!srcPlace");
        require(places.contains(dstPlace), "!dstPlace");

        uint received = _exchangeRenown(player, srcPlace, srcAmount, address(this));
        return _exchangeRenown(player, address(this), received, dstPlace);
    }

    // TODO: helper for calculation renown trades for destAmounts?


    function mintRenown(uint player, uint amount) external {
        require(msg.sender == address(surroundingPlace));
        _mintRenown(player, amount);
    }

    function _mintRenown(uint player, uint amount) internal {
        if (amount > 0) {
            renownOf[player] += amount;
            totalRenown += amount;
            emit RenownUp(player, amount);
        }
    }

    function spendRenown(uint player, uint amount) external {
        require(msg.sender == address(surroundingPlace));
        _spendRenown(player, amount);
    }

    function _spendRenown(uint player, uint amount) internal {
        renownOf[player] -= amount;
        totalRenown -= amount;
        emit RenownDown(player, amount);
    }

    ///
    /// Administration functions
    ///

    /** @dev TODO
    
        setOwner
        setCapacity
        setClasses (and levelCap and Destinations)
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
