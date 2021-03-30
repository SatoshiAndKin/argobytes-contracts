import brownie
import click
import os
import threading
import multiprocessing

from argobytes import (
    Action,
    approve,
    CallType,
    get_balances,
    get_claimable_3crv,
    print_token_balances,
)
from argobytes.contracts import (
    ArgobytesFactory,
    ArgobytesFlashBorrower,
    DyDxFlashLender,
    ExitCYY3CRVAction,
    get_or_clone,
    get_or_create,
    lazy_contract,
    poke_contracts,
)
from brownie import accounts, Contract, ZERO_ADDRESS
from brownie.network.web3 import _resolve_address
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from dotenv import load_dotenv, find_dotenv
from pprint import pprint


@click.command()
def simple_exit():
    """Make a bunch of transactions to withdraw from a leveraged cyy3crv position."""
    account = accounts.at(os.environ["LEVERAGE_ACCOUNT"])
    print(f"Hello, {account}")

    # TODO: prompt for slippage amount
    slippage = 0.1

    # TODO: use salts for the contracts once we figure out a way to store them. maybe 3box?

    # deploy our contracts if necessary
    argobytes_factory = get_or_create(account, ArgobytesFactory)
    argobytes_flash_borrower = get_or_create(account, ArgobytesFlashBorrower)

    # TODO: we only use this for the constants. don't waste gas deploying this on mainnet if it isn't needed
    exit_cyy3crv_action = get_or_create(account, ExitCYY3CRVAction)

    # get the clone for the account
    argobytes_clone = get_or_clone(account, argobytes_factory, argobytes_flash_borrower)

    assert account == argobytes_clone.owner(), "Wrong owner detected!"

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    dai = lazy_contract(exit_cyy3crv_action.DAI())
    usdc = lazy_contract(exit_cyy3crv_action.USDC())
    usdt = lazy_contract(exit_cyy3crv_action.USDT())
    threecrv = lazy_contract(exit_cyy3crv_action.THREE_CRV())
    threecrv_pool = lazy_contract(exit_cyy3crv_action.THREE_CRV_POOL())
    y3crv = lazy_contract(exit_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = lazy_contract(exit_cyy3crv_action.CY_Y_THREE_CRV())
    cydai = lazy_contract(exit_cyy3crv_action.CY_DAI())
    fee_distribution = lazy_contract(exit_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION())
    cream = lazy_contract(exit_cyy3crv_action.CREAM())

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv, cydai]

    balances = get_balances(account, tokens)
    print_token_balances(balances, f"{account} balances")

    # TODO: calculate/prompt for these
    #  StableSwap.calc_withdraw_one_coin(_token_amount: uint256, i: int128) → uint256
    min_remove_liquidity_dai = 1
    tip_dai = 0
    # TODO: this should be False in the default case
    exit_from_account = False
    # min_cream_liquidity = 1
