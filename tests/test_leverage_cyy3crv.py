from decimal import Decimal

import pytest
from brownie import accounts

from argobytes.cli.leverage_cyy3crv import atomic_enter, atomic_exit
from argobytes.contracts import load_contract
from argobytes.tokens import transfer_token


@pytest.mark.require_network("mainnet-fork")
def test_atomic_scripts(
    argobytes_flash_clone,
    click_test_runner,
    exit_cyy3crv_action,
    unlocked_binance,
):
    account = accounts[0]

    dai = load_contract(exit_cyy3crv_action.DAI())
    usdc = load_contract(exit_cyy3crv_action.USDC())
    usdt = load_contract(exit_cyy3crv_action.USDT())
    threecrv = load_contract(exit_cyy3crv_action.THREE_CRV())
    threecrv_pool = load_contract(exit_cyy3crv_action.THREE_CRV_POOL())
    y3crv = load_contract(exit_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = load_contract(exit_cyy3crv_action.CY_Y_THREE_CRV())

    initial_dai = Decimal(10000)

    # borrow some tokens from binance
    transfer_token(unlocked_binance, accounts[0], dai, initial_dai)
    # transfer_token(unlocked_binance, accounts[0], usdc, 10000)
    # transfer_token(unlocked_binance, accounts[0], usdt, 10000)

    enter_result = click_test_runner(atomic_enter, ["--account", str(account)])

    assert enter_result.exit_code == 0

    # make sure balances are what we expect
    assert dai.balanceOf(argobytes_flash_clone) == 0
    assert dai.balanceOf(account) == 0
    assert usdc.balanceOf(argobytes_flash_clone) == 0
    assert usdc.balanceOf(account) == 0
    assert usdt.balanceOf(argobytes_flash_clone) == 0
    assert usdt.balanceOf(account) == 0
    assert threecrv.balanceOf(argobytes_flash_clone) == 0
    assert threecrv.balanceOf(account) == 0
    assert y3crv.balanceOf(argobytes_flash_clone) == 0
    assert y3crv.balanceOf(account) == 0
    assert cyy3crv.balanceOf(argobytes_flash_clone) > 0
    assert cyy3crv.balanceOf(account) == 0

    # TODO: make sure we can't get liquidated (though i think the borrow would have reverted)

    # simulate some trades so that 3pool increases in value
    # TODO: make some actual trades?
    # TODO: how much DAI actually needs to be added to the pool
    transfer_token(unlocked_binance, exit_cyy3crv_action.THREE_CRV_POOL(), dai, 1000000)

    exit_result = click_test_runner(atomic_exit, ["--account", str(account)])

    assert exit_result.exit_code == 0

    threecrv_balance = threecrv.balanceOf(account)

    threecrv_balance_as_dai = Decimal(threecrv_balance) * Decimal(threecrv_pool.get_virtual_price()) / Decimal("1e18")

    # make sure balances are what we expect
    assert dai.balanceOf(argobytes_flash_clone) == 0
    assert dai.balanceOf(account) == 0
    assert usdc.balanceOf(argobytes_flash_clone) == 0
    assert usdc.balanceOf(account) == 0
    assert usdt.balanceOf(argobytes_flash_clone) == 0
    assert usdt.balanceOf(account) == 0
    assert threecrv.balanceOf(argobytes_flash_clone) == 0
    assert threecrv_balance > 0
    assert threecrv_balance_as_dai > initial_dai
    assert y3crv.balanceOf(argobytes_flash_clone) == 0
    assert y3crv.balanceOf(account) == 0
    assert cyy3crv.balanceOf(argobytes_flash_clone) == 0
    assert cyy3crv.balanceOf(account) == 0
