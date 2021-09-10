import itertools

from argobytes.contracts import ArgobytesBrownieProject, get_or_create, lazy_contract
from brownie import chain, history, multicall
from click_spinner import spinner
from gql import Client, gql
from gql.transport.requests import RequestsHTTPTransport

RARITY = lazy_contract("0xce761d788df608bd21bdd59d6f4b54b2e27f25bb")

# i'd like to use the singleton deployer, but it doesn't appear to work on ftm
RARITY_ACTION_V1 = lazy_contract("0x0fD89B2430Bec282962bb1D012b22b7fD3d0db58")


def grouper(iterable, n, fillvalue=None):
    """Collect data into fixed-length chunks or blocks

    https://docs.python.org/3/library/itertools.html
    """
    # grouper('ABCDEFG', 3, 'x') --> ABC DEF Gxx"
    args = [iter(iterable)] * n
    return itertools.zip_longest(*args, fillvalue=fillvalue)


def get_summoners(account):
    # Select your transport with a defined url endpoint
    transport = RequestsHTTPTransport(url="https://api.thegraph.com/subgraphs/name/eabz/rarity")

    # Create a GraphQL client using the defined transport
    client = Client(transport=transport, fetch_schema_from_transport=True)

    # TODO: compare graphql result with balanceOf
    # TODO: also query level and class? anything else? gold?
    # TODO: how should we paginate? https://thegraph.com/docs/developer/graphql-api#pagination isn't working for me
    query = gql(
        """
    {{
        summoners(where: {{owner: "{account}"}}, first: 1000) {{
            id
        }}
    }}
    """.format(
            account=account.address.lower()
        )
    )

    result = client.execute(query)

    summoners = [x["id"] for x in result["summoners"]]

    # TODO: scan transactions for new summoners if the balance doesn't match

    return summoners


# TODO: set attributes, name, title. what else?
# TODO: farm rarity gems


def adventure(account):
    summoners = get_summoners(account)

    print(f"{account} has {len(summoners)} known summoners")

    rarity_balance = RARITY.balanceOf(account)
    if rarity_balance != len(summoners):
        print(f"WARNING! Only {len(summoners)}/{rarity_balance} summoner ids are known!")

    if not RARITY.isApprovedForAll(account, RARITY_ACTION_V1):
        RARITY.setApprovalForAll(RARITY_ACTION_V1, True, {"from": account}).info()

    # Version numbering is going to be tedious. so is approving every time a new contract comes out
    # get our clone proxies deployed on FTM and then approve that instead?

    print("Querying adventure logs...")
    with spinner():
        with multicall:
            adventurers_logs = [(RARITY.adventurers_log(s), s) for s in summoners]
            # TODO: check adventure logs and scouting for RARITY_CELLAR

    now = chain[-1].timestamp

    adventurers_logs.sort()

    next_run = now + 86400

    for (l, s) in adventurers_logs:
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
        RARITY_ACTION_V1.adventure(list(filter(None, a)), {"required_confs": 0})

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


def create_town(account):
    # wildland (w/ barbs)
    # tavern (w/ bards)
    # temple (w/ clerics)
    # standing_stones (w/ druids)
    # barracks (w/ fighters)
    # marketplace (w/ rogues training to be LPs on https://rarity.game's market)
    # monastary (w/ monks)
    # temple barracks (w/ paladins)
    # forest (w/ ranger. needs better name)
    # sorcerers_guild (needs better name)
    # arcane tower (w/ wizards)

    # mercenary_camp (sells all the summoners that leveled out of the other buildings)
    # as the contracts are written now, we will need a different camp for each 

    # allow people to create a house. houses can have their size increased by spending renown. working will rotate through the houses
