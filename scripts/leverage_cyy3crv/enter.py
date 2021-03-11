import os
import threading
import multiprocessing

from argobytes_util import Action, approve, get_balances, DyDxFlashLender, get_or_clone, get_or_create, lazy_contract, poke_contracts
from brownie import accounts, ArgobytesFactory, ArgobytesFlashBorrower, Contract, EnterCYY3CRVAction
from brownie.network.web3 import _resolve_address
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from dotenv import load_dotenv, find_dotenv
from pprint import pprint


EnterData = namedtuple("EnterData", [
    "dai",
    "dai_flash_fee",
    "usdc",
    "usdt",
    "min_3crv_mint_amount",
    "threecrv",
    "tip_3crv",
    "y3crv",
    "min_cream_liquidity",
    "sender",
    "tip_address",
    "claim_3crv",
])


def get_claimable_3crv(account, fee_distribution, min_crv=50):
    claimable = fee_distribution.claim.call(account)

    if claimable < min_crv:
        return 0
    
    return claimable


def main():
    load_dotenv(find_dotenv())

    # TODO: we need an account with private keys
    account = accounts.at(os.environ['LEVERAGE_ACCOUNT'])

    min_3crv_to_claim = os.environ.get("MIN_3CRV_TO_CLAIM", 50)

    # TODO: different salts for each contract
    salt = ""

    # deploy our contracts if necessary
    argobytes_factory = get_or_create(account, ArgobytesFactory, salt)
    argobytes_flash_borrower = get_or_create(account, ArgobytesFlashBorrower, salt)
    enter_cyy3crv_action = get_or_create(account, EnterCYY3CRVAction, salt)

    # get the clone for the account
    argobytes_clone = get_or_clone(account, argobytes_factory, argobytes_flash_borrower, salt)

    assert account == argobytes_clone.owner(), "Wrong owner detected!"

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    dai = lazy_contract(enter_cyy3crv_action.DAI())
    usdc = lazy_contract(enter_cyy3crv_action.USDC())
    usdt = lazy_contract(enter_cyy3crv_action.USDT())
    threecrv = lazy_contract(enter_cyy3crv_action.THREE_CRV())
    threecrv_pool = lazy_contract(enter_cyy3crv_action.THREE_CRV_POOL())
    y3crv = lazy_contract(enter_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = lazy_contract(enter_cyy3crv_action.CY_Y_THREE_CRV())
    fee_distribution = lazy_contract(enter_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION())
    lender = DyDxFlashLender

    # use multiple workers to fetch the contracts
    # there will still be some to fetch, but this speeds things up some
    # this can take some time since solc/vyper may have to download
    poke_contracts([dai, usdc, usdt, threecrv, threecrv_pool, y3crv, cyy3crv, lender])

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv]

    balances = get_balances(account, tokens)
    print(f"{account} balances")
    pprint(balances)

    claimable_3crv = get_claimable_3crv(account, fee_distribution, min_3crv_to_claim)

    # TODO: calculate/prompt for these
    min_3crv_mint_amount = 1
    tip_3crv = 1
    tip_address = _resolve_address("satoshiandkin.eth")  # TODO: put this on a subdomain and uses an immutable
    min_cream_liquidity = 1

    enter_data = EnterData(
        dai=balances[dai],
        dai_flash_fee=None,
        usdc=balances[usdc],
        usdt=balances[usdt],
        min_3crv_mint_amount=min_3crv_mint_amount,
        threecrv=balances[threecrv],
        tip_3crv=tip_3crv,
        y3crv=balances[y3crv],
        min_cream_liquidity=min_cream_liquidity,
        sender=account,
        tip_address=tip_address,
        claim_3crv=claimable_3crv > min_3crv_to_claim,
    )

    # TODO: do this properly. use virtualprice and yearn's price calculation 
    print("warning! summed_balances is not actually priced in USD")
    summed_balances = enter_data.dai + enter_data.usdc + enter_data.usdt + enter_data.threecrv + enter_data.y3crv + claimable_3crv

    assert summed_balances > 100, "no coins"

    # TODO: figure out the actual max leverage, then prompt the user for it (though i dont see much reason not to go the full amount here)
    flash_loan_amount = int(summed_balances * 8.4)

    enter_data = enter_data._replace(dai_flash_fee=lender.flashFee(dai, flash_loan_amount))

    pprint(enter_data)

    extra_balances = {}

    if enter_data.claim_3crv:
        extra_balances[threecrv.address] = claimable_3crv

    approve(account, balances, extra_balances, argobytes_clone)

    # flashloan through the clone
    enter_tx = argobytes_clone.flashBorrow(
        lender,
        dai,
        flash_loan_amount,
        Action(
            enter_cyy3crv_action,
            "delegate",
            False,
            "enter",
            enter_data,
        ).tuple,
    )

    print("enter success!")
    enter_tx.info()

    num_events = enter_tx.events.len()
    print(f"num events: {num_events}")

    print("clone balances")
    # TODO: print the keys as the token symbols
    pprint(get_balances(argobytes_clone, tokens))

    print("account balances")
    pprint(get_balances(account, tokens))
