import os
import threading
import multiprocessing

from argobytes_util import Action, approve, CallType, get_balances, get_claimable_3crv, DyDxFlashLender, get_or_clone, get_or_create, lazy_contract, poke_contracts, pprint_balances
from brownie import accounts, ArgobytesFactory, ArgobytesFlashBorrower, Contract, EnterCYY3CRVAction
from brownie.network.web3 import _resolve_address
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from dotenv import load_dotenv, find_dotenv
from eth_utils import to_int
from pprint import pprint


def main():
    load_dotenv(find_dotenv())

    # TODO: we need an account with private keys
    account = accounts.at(os.environ['LEVERAGE_ACCOUNT'])
    print(f"Hello, {account}")

    min_3crv_to_claim = os.environ.get("MIN_3CRV_TO_CLAIM", 50)

    # deploy our contracts if necessary
    enter_cyy3crv_action = get_or_create(account, EnterCYY3CRVAction)

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    dai = lazy_contract(enter_cyy3crv_action.DAI())
    usdc = lazy_contract(enter_cyy3crv_action.USDC())
    usdt = lazy_contract(enter_cyy3crv_action.USDT())
    threecrv = lazy_contract(enter_cyy3crv_action.THREE_CRV())
    threecrv_pool = lazy_contract(enter_cyy3crv_action.THREE_CRV_POOL())
    y3crv = lazy_contract(enter_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = lazy_contract(enter_cyy3crv_action.CY_Y_THREE_CRV())
    cydai = lazy_contract(enter_cyy3crv_action.CY_DAI())
    fee_distribution = lazy_contract(enter_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION())
    cream = lazy_contract(enter_cyy3crv_action.CREAM())
    lender = DyDxFlashLender

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv]

    balances = get_balances(account, tokens)
    print(f"{account} balances")
    pprint_balances(balances)

    claimable_3crv = get_claimable_3crv(account, fee_distribution, min_3crv_to_claim)

    # TODO: calculate/prompt for these
    min_3crv_mint_amount = 1
    tip_3crv = 0
    tip_address = _resolve_address("satoshiandkin.eth")  # TODO: put this on a subdomain and uses an immutable
    min_cream_liquidity = 1000

    # TODO: do this properly. use virtualprice and yearn's price calculation 
    # print("warning! summed_balances is not actually priced in USD")
    # summed_balances = enter_data.dai + enter_data.usdc + enter_data.usdt + enter_data.threecrv + enter_data.y3crv + claimable_3crv
    # assert summed_balances > 100, "no coins"

    balances_for_3crv_pool = {
        dai: balances[dai],
        usdc: balances[usdc],
        usdt: balances[usdt],
    }

    approve(account, balances_for_3crv_pool, {}, threecrv_pool)

    threecrv_pool.add_liquidity(
        [
            balances_for_3crv_pool[dai],
            balances_for_3crv_pool[usdc],
            balances_for_3crv_pool[usdt],
        ],
        min_3crv_mint_amount,
        {"from": account},
    )

    if claimable_3crv >= min_3crv_to_claim:
        fee_distribution.claim({"from": account})

    # TODO: tip the developer in 3crv/ETH

    # deposit 3crv for y3crv
    balances_for_y3crv = get_balances(account, [threecrv])

    approve(account, balances_for_y3crv, {}, y3crv)

    y3crv.deposit(balances_for_y3crv[threecrv], {"from": account})

    # setup cream
    cream_cyy3crv_member = cream.checkMembership(account, cyy3crv)
    cream_cydai_member = cream.checkMembership(account, cydai)

    markets = []
    if cream_cyy3crv_member:
        markets.append(cyy3crv)
    if cream_cydai_member:
        markets.append(cydai)

    if markets:
        cream.enterMarkets(markets, {"from": account})

    # deposit y3crv for cyy3crv
    balances_for_cyy3crv = get_balances(account, [y3crv])

    approve(account, balances_for_cyy3crv, {}, cyy3crv)

    cyy3crv.mint(balances_for_cyy3crv[y3crv], {"from": account})

    raise NotImplementedError("wip")

    print(f"enter simple success! {enter_tx.return_value}")

    """
    if not cream.

    enter_tx.info()

    num_events = len(enter_tx.events)
    print(f"num events: {num_events}")

    enter_return = to_int(enter_tx.return_value)

    print(f"return value: {enter_return}")

    assert enter_return > 0, "no cyy3ccrv returned!"

    print(f"clone ({argobytes_clone.address}) balances")
    balances = get_balances(argobytes_clone, tokens)
    pprint_balances(balances)

    # TODO: why is this not working? we return cyy3crv.balanceOf!
    # assert balances[cyy3crv] == enter_tx.return_value

    # TODO: make sure the clone has cyy3crv?

    print(f"account ({account}) balances")
    pprint_balances(get_balances(account, tokens))
    """