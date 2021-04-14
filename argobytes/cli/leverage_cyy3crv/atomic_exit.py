import os
from collections import namedtuple
from pprint import pprint

import brownie
import click
from brownie import ZERO_ADDRESS, Contract, accounts
from brownie.network.web3 import _resolve_address

from argobytes.contracts import (
    ArgobytesAction,
    ArgobytesActionCallType,
    ArgobytesFactory,
    ArgobytesFlashBorrower,
    DyDxFlashLender,
    ExitCYY3CRVAction,
    get_or_clone,
    get_or_create,
    lazy_contract,
    poke_contracts,
)
from argobytes.tokens import get_balances, get_claimable_3crv, print_token_balances, safe_token_approve
from argobytes.web3_helpers import get_average_block_time

ExitData = namedtuple("ExitData", ["dai_flash_fee", "max_3crv_burned", "tip_3crv", "sender",],)


def atomic_exit(account, tip_eth, tip_3crv):
    """Use a flash loan to withdraw from a leveraged cyy3crv position."""
    # TODO: we need an account with private keys
    print(f"Hello, {account}")

    # 0.5 is 0.5%
    # slippage = ['small', 'medium', 'high', 'bad idea']
    slippage_pct = 0.5  # TODO: this should be a click arg

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
    dai = lazy_contract(exit_cyy3crv_action.DAI(), account)
    usdc = lazy_contract(exit_cyy3crv_action.USDC(), account)
    usdt = lazy_contract(exit_cyy3crv_action.USDT(), account)
    threecrv = lazy_contract(exit_cyy3crv_action.THREE_CRV(), account)
    threecrv_pool = lazy_contract(exit_cyy3crv_action.THREE_CRV_POOL(), account)
    y3crv = lazy_contract(exit_cyy3crv_action.Y_THREE_CRV(), account)
    cyy3crv = lazy_contract(exit_cyy3crv_action.CY_Y_THREE_CRV(), account)
    cydai = lazy_contract(exit_cyy3crv_action.CY_DAI(), account)
    lender = DyDxFlashLender

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv, cydai]

    # use multiple workers to fetch the contracts
    # there will still be some to fetch, but this speeds things up some
    # this can take some time since solc/vyper may have to download
    poke_contracts(tokens + [threecrv_pool, lender])

    balances = get_balances(argobytes_clone, tokens)
    print(f"clone {argobytes_clone} balances")

    print_token_balances(balances)

    dai_borrowed = cydai.borrowBalanceCurrent.call(argobytes_clone)
    assert dai_borrowed > 0, "No DAI position to exit from"

    print(f"dai_borrowed:      {dai_borrowed}")

    borrow_rate_per_block = cydai.borrowRatePerBlock.call()

    # TODO: how many blocks of interest should we add on? base this on gas speed?
    # TODO: is this right? i think it might be overshooting. i don't think it matters that much though
    interest_slippage_blocks = int((5 * 60) / get_average_block_time())
    # https://www.geeksforgeeks.org/python-program-for-compound-interest/
    flash_loan_amount = int(dai_borrowed * (pow((1 + borrow_rate_per_block / 1e18), interest_slippage_blocks)))

    print(f"flash_loan_amount: {flash_loan_amount}")

    # safety check. make sure our interest doesn't add a giant amount
    assert flash_loan_amount <= dai_borrowed * (1 + slippage_pct / 100)

    flash_loan_fee = lender.flashFee(dai, flash_loan_amount)

    print(f"flash_loan_fee: {flash_loan_fee}")

    # TODO: safety check on the flash loan fee?

    # TODO: this is slightly high because we add 5 minutes of interest. we could spend gas subtracting out the unused slack, but i doubt its worthwhile
    max_3crv_burned = threecrv_pool.calc_token_amount(
        # dai, usdc, usdt
        [flash_loan_amount + flash_loan_fee, 0, 0,],
        # is_deposit
        False,
    ) * (1 + slippage_pct / 100)

    exit_data = ExitData(
        dai_flash_fee=flash_loan_fee, max_3crv_burned=max_3crv_burned, tip_3crv=tip_3crv, sender=account,
    )

    pprint(exit_data)

    safe_token_approve(account, balances, argobytes_clone)

    # flashloan through the clone
    exit_tx = argobytes_clone.flashBorrow(
        lender,
        dai,
        flash_loan_amount,
        ArgobytesAction(exit_cyy3crv_action, ArgobytesActionCallType.DELEGATE, False, "exit", *exit_data,).tuple,
        {"value": tip_eth,},
    )

    print("exit success!")
    # exit_tx.info()

    # num_events = len(exit_tx.events)
    # print(f"num events: {num_events}")

    print(f"gas used: {exit_tx.gas_used}")

    print("clone balances")
    print_token_balances(get_balances(argobytes_clone, tokens))

    print("account balances")
    print_token_balances(get_balances(account, tokens))
