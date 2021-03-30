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
    ArgobytesInterfaces,
    ArgobytesFactory,
    ArgobytesFlashBorrower,
    DyDxFlashLender,
    ExitCYY3CRVAction,
    get_or_clone,
    get_or_create,
    load_contract,
)
from brownie import accounts, Contract, ZERO_ADDRESS
from brownie.network.web3 import _resolve_address
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from dotenv import load_dotenv, find_dotenv
from pprint import pprint


@click.command()
@click.option("--exit-from-account/--exit-from-clone", default=False)
def simple_exit(exit_from_account):
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

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    # TODO: i want to use IERC20, but it lacks getters for the state variables
    dai = load_contract(exit_cyy3crv_action.DAI(), account)
    usdc = load_contract(exit_cyy3crv_action.USDC(), account)
    usdt = load_contract(exit_cyy3crv_action.USDT(), account)
    threecrv = load_contract(exit_cyy3crv_action.THREE_CRV(), account)
    threecrv_pool = ArgobytesInterfaces.ICurvePool(
        exit_cyy3crv_action.THREE_CRV_POOL(), account
    )
    y3crv = ArgobytesInterfaces.IYVault(exit_cyy3crv_action.Y_THREE_CRV(), account)
    cyy3crv = ArgobytesInterfaces.ICERC20(exit_cyy3crv_action.CY_Y_THREE_CRV(), account)
    cydai = ArgobytesInterfaces.ICERC20(exit_cyy3crv_action.CY_DAI(), account)
    fee_distribution = ArgobytesInterfaces.ICurveFeeDistribution(
        exit_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION(), account
    )
    cream = ArgobytesInterfaces.IComptroller(exit_cyy3crv_action.CREAM(), account)

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv, cydai]

    start_balances = get_balances(account, tokens)
    print_token_balances(start_balances, f"{account} start balances")

    # approve 100%. if we approve borrowBalance, then we leave some dust behind since the approve transaction adds a block of interest
    # also, since this is a simple exit, we will probably have to run this again
    approve(account, {dai: start_balances[dai]}, {}, cydai)

    borrow_balance = cydai.borrowBalanceCurrent.call(account)

    assert (
        start_balances[dai] >= borrow_balance
    ), f"not enough DAI: {start_balances[dai]} < {borrow_balance}"

    cydai.repayBorrow(borrow_balance)

    cyy3crv_balance = cyy3crv.balanceOf(account)

    assert cyy3crv.redeem(cyy3crv_balance).return_value == 0

    y3crv_balance = y3crv.balanceOf(account)

    y3crv.withdraw(y3crv_balance)

    threecrv_balance = threecrv.balanceOf(account)

    threecrv.approve(threecrv_pool, threecrv_balance)

    # TODO: change this to exit to 3crv
    threecrv_pool.remove_liquidity_one_coin(threecrv_balance, 0, borrow_balance)

    end_balances = get_balances(account, tokens)
    print_token_balances(end_balances, f"{account} end balances")

    assert end_balances[dai] > start_balances[dai]
