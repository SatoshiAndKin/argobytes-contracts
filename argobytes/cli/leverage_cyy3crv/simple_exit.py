from decimal import Decimal

import brownie
import click
from brownie import ZERO_ADDRESS, Contract, accounts
from brownie.network.web3 import _resolve_address

from argobytes.contracts import (
    ArgobytesBrownieProject,
    ArgobytesInterfaces,
    get_or_create,
    load_contract,
    poke_contracts,
)
from argobytes.tokens import (
    get_balances,
    get_token_decimals,
    print_token_balances,
    safe_token_approve,
)


def simple_exit(account):
    """Make a bunch of transactions to withdraw from a leveraged cyy3crv position."""
    print(f"Hello, {account}")

    # TODO: flag for slippage amount. default 0.5%

    # TODO: use salts for the contracts once we figure out a way to store them. maybe 3box?

    # TODO: we only use this for the constants. don't waste gas deploying this on mainnet if it isn't needed
    exit_cyy3crv_action = get_or_create(account, ArgobytesBrownieProject.ExitCYY3CRVAction)

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    # TODO: i want to use IERC20, but it lacks getters for the state variables
    dai = load_contract(exit_cyy3crv_action.DAI(), owner=account)
    usdc = load_contract(exit_cyy3crv_action.USDC(), owner=account)
    usdt = load_contract(exit_cyy3crv_action.USDT(), owner=account)
    threecrv = load_contract(exit_cyy3crv_action.THREE_CRV(), owner=account)
    threecrv_pool = load_contract(exit_cyy3crv_action.THREE_CRV_POOL(), owner=account, force=True)
    y3crv = load_contract(exit_cyy3crv_action.Y_THREE_CRV(), owner=account, force=True)
    cyy3crv = load_contract(exit_cyy3crv_action.CY_Y_THREE_CRV(), owner=account, force=True)
    cydai = load_contract(exit_cyy3crv_action.CY_DAI(), owner=account, force=True)
    cream = load_contract(exit_cyy3crv_action.CREAM(), owner=account, force=True)

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv, cydai]

    poke_contracts(tokens + [threecrv_pool, cream])

    # TODO: compare all these contracts with our own implementations

    start_balances = get_balances(account, tokens)

    print_token_balances(start_balances, f"{account} start balances")

    # approve 100%. if we approve borrowBalance, then we leave some dust behind since the approve transaction adds a block of interest
    # also, since this is a simple exit, we will probably have to run this again
    safe_token_approve(account, {dai: start_balances[dai]}, cydai)

    borrow_balance = cydai.borrowBalanceCurrent.call(account)
    print(f"cyDAI borrow_balance: {borrow_balance / 1e18}")

    # TODO: add a few blocks worth of interest just in case?

    # repay as much DAI as we can
    if start_balances[dai] == 0:
        # we do not have any DAI to repay. hopefully there is some headroom, or might take a lot of loops
        # TODO: click.confirm this?
        pass
    elif start_balances[dai] > borrow_balance:
        # we have more DAI than we need. repay the full balance
        # TODO: why do we need "from" here?
        repay_borrow_tx = cydai.repayBorrow(borrow_balance, {"from": account})

        repay_borrow_tx.info()
    else:
        # we do not have enough DAI. repay what we can
        # TODO: skip this if its a small amount?
        # TODO: why do we need "from" here?
        repay_borrow_tx = cydai.repayBorrow(start_balances[dai], {"from": account})

        repay_borrow_tx.info()

    # we need more DAI!
    # calculate how much cyy3crv we can safely withdraw
    (error, liquidity, shortfall) = cream.getHypotheticalAccountLiquidity(account, cydai, 0, borrow_balance)
    assert error == 0
    assert shortfall == 0

    print(f"liquidity: {liquidity}")

    # TODO: convert liquidity into cyy3crv. then leave some headroom
    # TODO: get 0.9 out of state
    y3crv_decimals = get_token_decimals(y3crv)
    cyy3crv_decimals = get_token_decimals(cyy3crv)

    # TODO: i think we should be able to use cream's price oracle for this
    # TODO: how do we get the 90% out of the contract?
    # TODO: does leaving headroom make sense? how much? add it in only if this isn't the last repayment?
    available_cyy3crv_in_usd = liquidity / Decimal(0.90)

    print(f"available_cyy3crv_in_usd: {available_cyy3crv_in_usd}")

    available_cyy3crv_in_3crv = available_cyy3crv_in_usd / (
        Decimal(threecrv_pool.get_virtual_price()) / Decimal("1e18")
    )

    print(f"available_cyy3crv_in_3crv: {available_cyy3crv_in_3crv}")

    available_cyy3crv_in_y3crv = available_cyy3crv_in_3crv / (
        Decimal(y3crv.getPricePerFullShare.call()) / Decimal("1e18")
    )

    print(f"available_cyy3crv_in_y3crv: {available_cyy3crv_in_y3crv}")

    one_cyy3crv_in_y3crv = Decimal(cyy3crv.exchangeRateCurrent.call()) / Decimal(
        10 ** (18 + y3crv_decimals - cyy3crv_decimals)
    )

    print(f"one_cyy3crv_in_y3crv: {one_cyy3crv_in_y3crv}")

    # TODO: this calculation is wrong
    available_cyy3crv = available_cyy3crv_in_y3crv // one_cyy3crv_in_y3crv

    print(f"available_cyy3crv: {available_cyy3crv}")

    # TODO: why do we need "from" here?
    redeem_tx = cyy3crv.redeem(available_cyy3crv, {"from": account})

    redeem_tx.info()

    # redeem returns 0 on success
    assert redeem_tx.return_value == 0

    y3crv_balance = y3crv.balanceOf(account)

    y3crv.withdraw(y3crv_balance, {"from": account})

    threecrv.balanceOf(account)

    end_balances = get_balances(account, tokens)
    print_token_balances(end_balances, f"{account} end balances")

    assert end_balances[threecrv] > start_balances[threecrv]
