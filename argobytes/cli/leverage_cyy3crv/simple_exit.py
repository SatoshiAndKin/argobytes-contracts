import brownie
import click
from brownie import ZERO_ADDRESS, Contract, accounts
from brownie.network.web3 import _resolve_address
from dotenv import find_dotenv, load_dotenv

from argobytes.cli_helpers import CommandWithAccount, brownie_connect
from argobytes.contracts import (
    ArgobytesAction,
    ArgobytesActionCallType,
    ArgobytesFactory,
    ArgobytesFlashBorrower,
    ArgobytesInterfaces,
    DyDxFlashLender,
    ExitCYY3CRVAction,
    get_or_clone,
    get_or_create,
    load_contract,
    poke_contracts,
)
from argobytes.tokens import (
    print_token_balances,
    get_token_decimals,
    token_approve,
    get_balances,
    get_claimable_3crv,
)


@click.command(cls=CommandWithAccount)
def simple_exit(account):
    """Make a bunch of transactions to withdraw from a leveraged cyy3crv position."""
    print(f"Hello, {account}")

    # TODO: flag for slippage amount. default 0.5%

    # TODO: use salts for the contracts once we figure out a way to store them. maybe 3box?

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
    cream = ArgobytesInterfaces.IComptroller(exit_cyy3crv_action.CREAM(), account)

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv, cydai]

    poke_contracts(tokens + [threecrv_pool, cream])

    start_balances = get_balances(account, tokens)

    print("start_balances:", start_balances)

    print_token_balances(start_balances, f"{account} start balances")

    # approve 100%. if we approve borrowBalance, then we leave some dust behind since the approve transaction adds a block of interest
    # also, since this is a simple exit, we will probably have to run this again
    approve(account, {dai: start_balances[dai]}, {}, cydai)

    borrow_balance = cydai.borrowBalanceCurrent.call(account)
    print(f"cyDAI borrow_balance: {borrow_balance}")

    # TODO: add a few blocks worth of interest just in case?

    # repay as much DAI as we can
    if start_balances[dai] == 0:
        # we do not have any DAI to repay. hopefully there is some headroom, or might take a lot of loops
        # TODO: click.confirm this?
        pass
    elif start_balances[dai] > borrow_balance:
        # we have more DAI than we need. repay the full balance
        cydai.repayBorrow(repay_balance)
    else:
        # we do not have enough DAI. repay what we can
        # TODO: skip this if its a small amount?
        cydai.repayBorrow(start_balances[dai])

    # we need more DAI!
    # calculate how much cyy3crv we can safely withdraw
    (error, liquidity, shortfall) = cream.getHypotheticalAccountLiquidity(
        account, cydai, 0, repay_balance
    )
    assert error == 0
    assert shortfall == 0

    # TODO: convert liquidity into cyy3crv. then leave some headroom
    # TODO: get 0.9 out of state
    y3crv_decimals = get_token_decimals(y3crv)
    cyy3crv_decimals = get_token_decimals(cyy3crv)

    # TODO: i think we should be able to use cream's price oracle for this
    # TODO: how do we get the 90% out of the contract?
    # TODO: does leaving headroom make sense? how much? add it in only if this isn't the last repayment?
    available_cyy3crv_in_usd = liquidity / Decimal(0.90)
    available_cyy3crv_in_3crv = available_cyy3crv_in_usd / (
        Decimal(threecrv_pool.get_virtual_price()) / Decimal(1e18)
    )
    available_cyy3crv_in_y3crv = available_cyy3crv_in_3crv / (
        Decimal(y3crv.getPricePerFullShare()) / Decimal(1e18)
    )

    one_cyy3crv_in_y3crv = Decimal(cyy3crv.exchangeRateCurrent.call()) / Decimal(
        10 ** (18 + y3crv_decimals - cyy3crv_decimals)
    )

    available_cyy3crv = available_cyy3crv_in_y3crv / one_cyy3crv_in_y3crv

    assert cyy3crv.redeem(available_cyy3crv).return_value == 0

    y3crv_balance = y3crv.balanceOf(account)

    y3crv.withdraw(y3crv_balance)

    threecrv.balanceOf(account)

    end_balances = get_balances(account, tokens)
    print_token_balances(end_balances, f"{account} end balances")

    assert end_balances[threecrv] > start_balances[threecrv]
