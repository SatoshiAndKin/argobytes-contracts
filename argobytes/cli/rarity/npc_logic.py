import itertools

import click
from brownie import ZERO_ADDRESS, chain, history, multicall
from click_spinner import spinner
from gql import Client, gql
from gql.transport.requests import RequestsHTTPTransport

from argobytes.contracts import ArgobytesBrownieProject, get_or_create, lazy_contract

from .rarity_logic import RARITY, RARITY_ACTION_V2, get_summoners, grouper

# TODO: set attributes, name, title. what else?
# TODO: farm rarity gems


def adventure(account):
    summoners = get_summoners(account)

    print(f"{account} has {len(summoners)} known summoners")

    rarity_balance = RARITY.balanceOf(account)
    if rarity_balance != len(summoners):
        print(f"WARNING! Only {len(summoners)}/{rarity_balance} summoner ids are known!")

    if not RARITY.isApprovedForAll(account, RARITY_ACTION_V2):
        RARITY.setApprovalForAll(RARITY_ACTION_V2, True, {"from": account, "required_confs": 0}).info()

    # Version numbering is going to be tedious. so is approving every time a new contract comes out
    # get our clone proxies deployed on FTM and then approve that instead?

    print("Querying adventure logs...")
    with spinner():
        with multicall:
            approvals = [(RARITY.getApproved(s), s) for s in summoners]
            adventurers_logs = [(RARITY.adventurers_log(s), s) for s in summoners]
            # TODO: check adventure logs and scouting for RARITY_CELLAR

    # approvalForAll doesn't work on all contracts
    for approved, summoner in approvals:
        if approved == RARITY_ACTION_V2.address:
            continue
        RARITY.approve(RARITY_ACTION_V2, summoner, {"from": account, "required_confs": 0})

    print("waiting for confirmations...")
    with spinner():
        history.wait()

    now = chain[-1].timestamp

    adventurers_logs.sort()

    next_run = now + 86400

    for (l, _) in adventurers_logs:
        if now < l:
            next_run = l + 1
            break

    print("next run needed in", next_run - now, "seconds")

    # filter out adventurers that have adventured too recently
    adventurers = [s for (l, s) in adventurers_logs if now > l]

    if not adventurers:
        print("No adventurers ready")
        # TODO: return next time we should run? schedule it?
        return next_run

    print(f"{account} has {len(adventurers)} summoners ready for adventure")

    # TODO: how many fit in one transaction? 15 failed in my quick testing, but do some more checking
    # TODO: ganache block limit is way less than actual mainnet. figure out a practical limit
    group_size = len(adventurers)
    for a in grouper(adventurers, group_size, None):
        RARITY_ACTION_V2.adventure(list(filter(None, a)), {"required_confs": 0})

    print("waiting for confirmations...")
    with spinner():
        history.wait()

    print("adventuring complete!")

    return next_run


def summon(account, class_id: int = 11, amount: int = 1, adventure: bool = False):
    if not RARITY.isApprovedForAll(account, RARITY_ACTION_V1):
        RARITY.setApprovalForAll(RARITY_ACTION_V1, True, {"from": account}).info()

    RARITY_ACTION_V1.summonFor(class_id, amount, adventure, account).info()

    with spinner():
        summoners = []
        for tx in history.from_sender(account):
            if "summoned" not in tx.events:
                continue

            for event in tx.events["summoned"]:
                summoners.append(event["summoner"])

    print("new summoners:", summoners)


def build_town(account, name):
    clone_factory = get_or_create(account, ArgobytesBrownieProject.CloneFactory)
    rarity_place = get_or_create(account, ArgobytesBrownieProject.RarityPlace, constructor_args=[clone_factory])

    placeClass = 1
    empty_salt = b"\x00" * 32

    my_town_tx = rarity_place.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        0,
        # uint[] calldata _classes,
        [],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [ZERO_ADDRESS] * 11,
        # string calldata _name,
        name,
        # uint _placeClass,
        placeClass,
        # uint _renownExchangeRate,
        0,
        # bytes32 _salt
        empty_salt,
    )
    my_town = ArgobytesBrownieProject.RarityPlace.at(my_town_tx.return_value, owner=account)
    print(f"town {name}:", click.style(my_town, fg="green"))

    # TODO: mercenary_camp (sells all the summoners that leveled out of the other buildings)
    mercenary_camp = ZERO_ADDRESS

    # place (w/ barbs)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [
            # The Cellar - https://andrecronje.medium.com/rarity-the-cellar-83a1606a0be3
            "0x2A0F1cB17680161cF255348dDFDeE94ea8Ca196A",
        ],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [1],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Wildlands",
        # uint _placeClass,
        1,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Wildlands:", click.style(place, fg="green"))

    # tavern (w/ bards)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [2],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "The Greasy Spoon",
        # uint _placeClass,
        2,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"The Greasy Spoon:", click.style(place, fg="green"))

    # temple (w/ clerics)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [3],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Temple",
        # uint _placeClass,
        3,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Temple:", click.style(place, fg="green"))

    # standing_stones (w/ druids)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [4],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Standing Stones",
        # uint _placeClass,
        4,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Standing Stones:", click.style(place, fg="green"))

    # barracks (w/ fighters)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [
            # The Cellar - https://andrecronje.medium.com/rarity-the-cellar-83a1606a0be3
            "0x2A0F1cB17680161cF255348dDFDeE94ea8Ca196A",
        ],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [5],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Barracks",
        # uint _placeClass,
        5,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Barracks:", click.style(place, fg="green"))

    # marketplace (w/ rogues training to be LPs on https://rarity.game's market)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [6],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Market District",
        # uint _placeClass,
        6,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Market District:", click.style(place, fg="green"))

    # monastary (w/ monks)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [7],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Monastary",
        # uint _placeClass,
        7,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Monastary:", click.style(place, fg="green"))

    # temple barracks (w/ paladins)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [
            # The Cellar - https://andrecronje.medium.com/rarity-the-cellar-83a1606a0be3
            "0x2A0F1cB17680161cF255348dDFDeE94ea8Ca196A",
        ],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [8],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Temple Barracks",
        # uint _placeClass,
        8,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Temple Barracks:", click.style(place, fg="green"))

    # forest (w/ ranger. needs better name)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [9],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Forest",
        # uint _placeClass,
        9,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Forest:", click.style(place, fg="green"))

    # sorcerers_guild (needs better name)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [10],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Sorcerer's Guild",
        # uint _placeClass,
        10,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Sorcerer's Guild:", click.style(place, fg="green"))

    # arcane tower (w/ wizards)
    deploy_tx = my_town.newPlace(
        # address[] calldata _adventures,
        [],
        # uint _capacity,
        2 ** 256 - 1,
        # uint[] calldata _classes,
        [11],
        # uint _levelCap,
        0,
        # address[11] calldata _levelCapDestinations,
        [mercenary_camp] * 11,
        # string calldata _name,
        "Arcane Tower",
        # uint _placeClass,
        11,
        # uint _renownExchangeRate,
        1e9,
        # bytes32 _salt
        empty_salt,
    )
    place = ArgobytesBrownieProject.RarityPlace.at(deploy_tx.return_value, owner=account)
    print(f"Arcane Tower:", click.style(place, fg="green"))

    # allow people to create a house. houses can have their size increased by spending renown. working will rotate through the houses

    print("Town complete")
