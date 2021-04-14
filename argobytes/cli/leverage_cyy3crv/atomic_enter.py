from collections import namedtuple
from decimal import Decimal
from pprint import pprint

import brownie
import click
from brownie import Contract, accounts
from brownie.network.web3 import _resolve_address
from eth_utils import to_int
from lazy_load import lazy

from argobytes.cli_helpers import CommandWithAccount, brownie_connect, logger
from argobytes.contracts import (
    ArgobytesAction,
    ArgobytesActionCallType,
    ArgobytesFactory,
    ArgobytesFlashBorrower,
    ArgobytesInterfaces,
    DyDxFlashLender,
    EnterCYY3CRVAction,
    get_or_clone,
    get_or_create,
    lazy_contract,
    poke_contracts,
)
from argobytes.tokens import (
    get_balances,
    get_claimable_3crv,
    print_token_balances,
    safe_token_approve,
)

EnterData = namedtuple(
    "EnterData",
    [
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
        "claim_3crv",
    ],
)


@click.command(cls=CommandWithAccount)
@click.option("--min-3crv-to-claim", default=50, show_default=True)
def atomic_enter(account, min_3crv_to_claim):
    """Use a flash loan to deposit into leveraged cyy3crv position."""
    logger.info(f"Hello, {account}")

    # deploy our contracts if necessary
    argobytes_factory = get_or_create(account, ArgobytesFactory)
    argobytes_flash_borrower = get_or_create(account, ArgobytesFlashBorrower)
    enter_cyy3crv_action = get_or_create(account, EnterCYY3CRVAction)

    # get the clone for the account
    argobytes_clone = get_or_clone(account, argobytes_factory, argobytes_flash_borrower)

    logger.info(f"clone: {argobytes_clone}")

    assert account == argobytes_clone.owner(), "Wrong owner detected!"

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    dai = lazy_contract(enter_cyy3crv_action.DAI())
    usdc = lazy_contract(enter_cyy3crv_action.USDC())
    usdt = lazy_contract(enter_cyy3crv_action.USDT())
    threecrv = lazy_contract(enter_cyy3crv_action.THREE_CRV())
    threecrv_pool = ArgobytesInterfaces.ICurvePool(enter_cyy3crv_action.THREE_CRV_POOL())
    y3crv = lazy_contract(enter_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = lazy_contract(enter_cyy3crv_action.CY_Y_THREE_CRV())
    fee_distribution = lazy_contract(enter_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION())
    lender = DyDxFlashLender

    assert threecrv_pool.coins(0) == dai.address
    assert threecrv_pool.coins(1) == usdc.address
    assert threecrv_pool.coins(2) == usdt.address
    # TODO: assert threecrv_pool.coins(3) == revert

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv]

    # use multiple workers to fetch the contracts
    # there will still be some to fetch, but this speeds things up some
    # this can take some time since solc/vyper may have to download
    # TODO: i think doing this in parallel might be confusiing things
    poke_contracts(tokens + [threecrv_pool, lender])

    balances = get_balances(account, tokens)
    print(f"{account} balances")
    print_token_balances(balances)

    claimable_3crv = get_claimable_3crv(account, fee_distribution, min_3crv_to_claim)

    # TODO: calculate/prompt for these
    min_3crv_mint_amount = 1
    tip_3crv = 0
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
        claim_3crv=claimable_3crv > min_3crv_to_claim,
    )

    # TODO: do this properly. use virtualprice and yearn's price calculation
    print("warning! summed_balances is not actually priced in USD")
    summed_balances = Decimal(
        enter_data.dai + enter_data.usdc + enter_data.usdt + enter_data.threecrv + enter_data.y3crv + claimable_3crv
    )

    print(f"summed_balances:   {summed_balances}")

    assert summed_balances > 100, "no coins"

    # TODO: figure out the actual max leverage, then prompt the user for it (though i dont see much reason not to go the full amount here)
    # TODO: if they have already done a flash loan once, we might be able to do a larger amount
    flash_loan_amount = int(summed_balances * Decimal(7.4))

    print(f"flash_loan_amount: {flash_loan_amount}")

    assert flash_loan_amount > 0, "no flash loan calculated"

    enter_data = enter_data._replace(dai_flash_fee=lender.flashFee(dai, flash_loan_amount))

    extra_balances = {}

    if enter_data.claim_3crv:
        extra_balances[threecrv.address] = claimable_3crv

    safe_token_approve(account, balances, argobytes_clone, extra_balances)

    # flashloan through the clone
    pprint(enter_data)
    enter_tx = argobytes_clone.flashBorrow(
        lender,
        dai,
        flash_loan_amount,
        ArgobytesAction(enter_cyy3crv_action, ArgobytesActionCallType.DELEGATE, False, "enter", enter_data,).tuple,
    )

    print("enter success!")

    """
    # TODO: this crashes ganache
    print(f"enter success! {enter_tx.return_value}")

    # TODO: this crashes ganache
    enter_tx.info()
    """

    # num_events = len(enter_tx.events)
    # print(f"num events: {num_events}")

    """
    # TODO: this crashes ganache
    enter_return = to_int(enter_tx.return_value)

    print(f"return value: {enter_return}")

    assert enter_return > 0, "no cyy3ccrv returned!"
    """

    # TODO: what should we set this to?
    # TODO: this should be in the tests, not here
    print(f"enter_tx.gas_used: {enter_tx.gas_used}")
    assert enter_tx.gas_used < 1200000

    print(f"clone ({argobytes_clone.address}) balances")
    balances = get_balances(argobytes_clone, tokens)
    print_token_balances(balances)

    print(f"account ({account}) balances")
    print_token_balances(get_balances(account, tokens))
