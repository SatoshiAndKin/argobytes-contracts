import pytest
from decimal import Decimal

from argobytes.tokens import transfer_token
from brownie import accounts, project
from click.testing import CliRunner

from argobytes.cli.leverage_cyy3crv import simple_enter, simple_exit


@pytest.mark.require_network("mainnet-fork")
def test_simple_scripts(
    click_test_runner, exit_cyy3crv_action, monkeypatch, unlocked_binance,
):
    account = accounts[0]

    # TODO: use flags instead of env?
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(account))

    dai = load_contract(exit_cyy3crv_action.DAI())
    usdc = load_contract(exit_cyy3crv_action.USDC())
    usdt = load_contract(exit_cyy3crv_action.USDT())
    threecrv = load_contract(exit_cyy3crv_action.THREE_CRV())
    threecrv_pool = load_contract(exit_cyy3crv_action.THREE_CRV_POOL())
    y3crv = load_contract(exit_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = load_contract(exit_cyy3crv_action.CY_Y_THREE_CRV())

    initial_dai = Decimal(10000)

    # borrow some tokens from binance
    transfer_token(unlocked_binance, account, dai, initial_dai)
    # transfer_token(unlocked_binance, account, usdc, 10000)
    # transfer_token(unlocked_binance, account, usdt, 10000)

    enter_result = click_test_runner(simple_enter)

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

    dai_needed = max(
        0, cydai.borrowBalanceCurrent.call(account) - dai.balanceOf(account)
    )

    if dai_needed:
        # pretend like we made money somewhere else and can close our loan
        transfer_token(unlocked_binance, account, dai, dai_needed)

    initial_dai = dai.balanceOf(account)

    exit_result = click_test_runner(simple_exit)

    assert exit_result.exit_code == 0

    # make sure we made a profit
    threecrv_balance = threecrv.balanceOf(account)

    threecrv_balance_as_dai = (
        Decimal(threecrv_balance)
        * Decimal(threecrv_pool.get_virtual_price())
        / Decimal(1e18)
    )

    assert dai.balanceOf(account) >= 0  # TODO: what should this amount be?
    assert usdc.balanceOf(account) == 0
    assert usdt.balanceOf(account) == 0
    assert threecrv_balance > 0
    assert threecrv_balance_as_dai > initial_dai
    assert y3crv.balanceOf(account) == 0
    assert cyy3crv.balanceOf(account) == 0
