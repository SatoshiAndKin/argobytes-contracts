import os
import threading
import multiprocessing

from argobytes_util import Action, approve, CallType, get_balances, get_claimable_3crv, DyDxFlashLender, get_or_clone, get_or_create, lazy_contract, poke_contracts, pprint_balances
from brownie import accounts, ArgobytesFactory, ArgobytesFlashBorrower, Contract, ExitCYY3CRVAction, ZERO_ADDRESS
from brownie.network.web3 import _resolve_address
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from dotenv import load_dotenv, find_dotenv
from pprint import pprint


ExitData = namedtuple("ExitData", [
    "min_remove_liquidity_dai",
    "tip_dai",
    "dai_flash_fee",
    "tip_address",
    "exit_from",
    "exit_to",
])


def main():
    load_dotenv(find_dotenv())

    # TODO: we need an account with private keys
    account = accounts.at(os.environ['LEVERAGE_ACCOUNT'])

    # TODO: prompt for slippage amount
    slippage = .1

    # TODO: use salts for the contracts once we figure out a way to store them. maybe 3box?

    # deploy our contracts if necessary
    argobytes_factory = get_or_create(account, ArgobytesFactory)
    argobytes_flash_borrower = get_or_create(account, ArgobytesFlashBorrower)
    exit_cyy3crv_action = get_or_create(account, ExitCYY3CRVAction)

    # get the clone for the account
    argobytes_clone = get_or_clone(account, argobytes_factory, argobytes_flash_borrower)

    assert account == argobytes_clone.owner(), "Wrong owner detected!"

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    # TODO: do we need all these for exit? or just enter?
    dai = lazy_contract(exit_cyy3crv_action.DAI())
    usdc = lazy_contract(exit_cyy3crv_action.USDC())
    usdt = lazy_contract(exit_cyy3crv_action.USDT())
    threecrv = lazy_contract(exit_cyy3crv_action.THREE_CRV())
    threecrv_pool = lazy_contract(exit_cyy3crv_action.THREE_CRV_POOL())
    y3crv = lazy_contract(exit_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = lazy_contract(exit_cyy3crv_action.CY_Y_THREE_CRV())
    fee_distribution = lazy_contract(exit_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION())
    lender = DyDxFlashLender

    # use multiple workers to fetch the contracts
    # there will still be some to fetch, but this speeds things up some
    # this can take some time since solc/vyper may have to download
    # poke_contracts([dai, usdc, usdt, threecrv, threecrv_pool, y3crv, cyy3crv, lender])

    # TODO: fetch other tokens?
    tokens = [cyy3crv]

    # TODO: calculate/prompt for these
    min_remove_liquidity_dai = 1
    tip_dai = 0
    tip_address = _resolve_address("satoshiandkin.eth")  # TODO: put this on a subdomain and uses an immutable
    # TODO: this should be False in the default case
    exit_from_account = False
    # min_cream_liquidity = 1

    if exit_from_account:
        exit_from = account
        exit_to = ZERO_ADDRESS

        balances = get_balances(exit_from, tokens)
        print(f"{exit_from} balances")

        raise NotImplementedError("we need an approve so CY_DAI.repayBorrowBehalf is allowed")
    else:
        exit_from = ZERO_ADDRESS
        exit_to = account

        balances = get_balances(argobytes_clone, tokens)
        print(f"{argobytes_clone} balances")

    pprint(balances)

    # TODO: ii think this might not be right
    flash_loan_amount = int(exit_cyy3crv_action.calculateExit.call(exit_from) * (1 + slippage))

    print(f"flash_loan_amount: {flash_loan_amount}")

    dai_flash_fee=lender.flashFee(dai, flash_loan_amount)

    exit_data = ExitData(
        min_remove_liquidity_dai=min_remove_liquidity_dai,
        tip_dai=tip_dai,
        dai_flash_fee=dai_flash_fee,
        tip_address=tip_address,
        exit_from=exit_from,
        # TODO: allow exiting to an arbitrary account
        exit_to=account,
    )

    pprint(exit_data)

    extra_balances = {}

    approve(account, balances, extra_balances, argobytes_clone)

    # flashloan through the clone
    exit_tx = argobytes_clone.flashBorrow(
        lender,
        dai,
        flash_loan_amount,
        Action(
            exit_cyy3crv_action,
            CallType.DELEGATE,
            False,
            "exit",
            *exit_data,
        ).tuple,
    )

    print("exit success!")
    exit_tx.info()

    num_events = len(enter_tx.events)
    print(f"num events: {num_events}")

    print("clone balances")
    pprint(get_balances(argobytes_clone, tokens))

    print("account balances")
    pprint(get_balances(account, tokens))
