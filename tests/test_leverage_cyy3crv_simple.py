from decimal import Decimal

from brownie import accounts

from argobytes.cli.leverage_cyy3crv import simple_enter, simple_exit
from argobytes.contracts import load_contract
from argobytes.tokens import transfer_token


def test_simple_scripts(
    click_test_runner,
    exit_cyy3crv_action,
    unlocked_binance,
):
    account = accounts[0]

    dai = load_contract(exit_cyy3crv_action.DAI())
    usdc = load_contract(exit_cyy3crv_action.USDC())
    usdt = load_contract(exit_cyy3crv_action.USDT())
    threecrv = load_contract(exit_cyy3crv_action.THREE_CRV())
    load_contract(exit_cyy3crv_action.THREE_CRV_POOL())
    y3crv = load_contract(exit_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = load_contract(exit_cyy3crv_action.CY_Y_THREE_CRV())
    load_contract(exit_cyy3crv_action.CY_DAI())

    initial_dai = Decimal(10000)

    # borrow some tokens from binance
    transfer_token(unlocked_binance, account, dai, initial_dai)
    # transfer_token(unlocked_binance, account, usdc, 10000)
    # transfer_token(unlocked_binance, account, usdt, 10000)

    # TODO: call enter multiple times
    for x in range(1):
        print(f"enter loop {x}")
        enter_result = click_test_runner(simple_enter, ["--account", str(account)])

        # TODO: if we didn't get very much, stop looping

        assert enter_result.exit_code == 0

    # TODO: make sure we can't get liquidated

    # make sure balances are what we expect
    assert dai.balanceOf(account) > 0
    assert usdc.balanceOf(account) == 0
    assert usdt.balanceOf(account) == 0
    assert threecrv.balanceOf(account) == 0
    assert y3crv.balanceOf(account) == 0
    assert cyy3crv.balanceOf(account) > 0

    # simulate some trades so that 3pool increases in value
    # TODO: make some actual trades? how much DAI actually needs to be added to the pool
    transfer_token(unlocked_binance, exit_cyy3crv_action.THREE_CRV_POOL(), dai, 200000)

    cyy3crv_balance = cyy3crv.balanceOf(account)

    # TODO: we will likely leave some dust behind. what is a reasonable amount? > 0 is probably too strict
    x = 0
    while cyy3crv_balance > 0 and x < 20:
        print(f"exit loop {x}")
        exit_result = click_test_runner(simple_exit, ["--account", str(account)])

        assert exit_result.exit_code == 0

        # TODO: save how much we print each time

        cyy3crv_balance = cyy3crv.balanceOf(account)
        x += 1

    assert dai.balanceOf(account) >= 0  # TODO: what should this amount be?
    assert usdc.balanceOf(account) == 0
    assert usdt.balanceOf(account) == 0
    assert threecrv.balanceOf(account) >= 0  # TODO: what should this amount be?
    assert y3crv.balanceOf(account) == 0
    assert cyy3crv.balanceOf(account) == 0
    assert x != 20, "too many loops"
