import brownie
import click
import os
import threading
import multiprocessing

from argobytes import Action, approve, CallType, get_balances, get_claimable_3crv, print_token_balances
from argobytes.contracts import DyDxFlashLender, get_or_clone, get_or_create, lazy_contract, poke_contracts
from brownie import accounts, Contract
from brownie.network.web3 import _resolve_address
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from lazy_load import lazy
from eth_utils import to_int
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


@click.command()
def atomic_enter():
    """Use a flash loan to deposit into leveraged cyy3crv position."""
    # TODO: we need an account with private keys
    account = accounts.at(os.environ['LEVERAGE_ACCOUNT'])
    print(f"Hello, {account}")

    min_3crv_to_claim = os.environ.get("MIN_3CRV_TO_CLAIM", 50)

    # deploy our contracts if necessary
    argobytes_factory = get_or_create(account, ArgobytesFactory)
    argobytes_flash_borrower = get_or_create(account, ArgobytesFlashBorrower)
    enter_cyy3crv_action = get_or_create(account, EnterCYY3CRVAction)

    # get the clone for the account
    argobytes_clone = get_or_clone(account, argobytes_factory, argobytes_flash_borrower)

    print(f"clone: {argobytes_clone}")

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
    # TODO: i think doing this in parallel might be confusiing things
    # poke_contracts([dai, usdc, usdt, threecrv, threecrv_pool, y3crv, cyy3crv, lender])

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv]

    balances = get_balances(account, tokens)
    print(f"{account} balances")
    print_token_balances(balances)

    claimable_3crv = get_claimable_3crv(account, fee_distribution, min_3crv_to_claim)

    # TODO: calculate/prompt for these
    min_3crv_mint_amount = 1
    tip_3crv = 0
    tip_address = _resolve_address("tip.satoshiandkin.eth")  # TODO: put this on a subdomain and uses an immutable
    min_cream_liquidity = 1000

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
    flash_loan_amount = int(summed_balances * 7.4)

    print(f"flash_loan_amount: {flash_loan_amount}")

    assert flash_loan_amount > 0, "no flash loan calculated"

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
            CallType.DELEGATE,
            False,
            "enter",
            enter_data,
        ).tuple,
    )

    print(f"enter success! {enter_tx.return_value}")

    enter_tx.info()

    num_events = len(enter_tx.events)
    print(f"num events: {num_events}")

    enter_return = to_int(enter_tx.return_value)

    print(f"return value: {enter_return}")

    assert enter_return > 0, "no cyy3ccrv returned!"

    print(f"clone ({argobytes_clone.address}) balances")
    balances = get_balances(argobytes_clone, tokens)
    print_token_balances(balances)

    # TODO: why is this not working? we return cyy3crv.balanceOf!
    # assert balances[cyy3crv] == enter_tx.return_value

    # TODO: make sure the clone has cyy3crv?

    print(f"account ({account}) balances")
    print_token_balances(get_balances(account, tokens))
