import pytest

from argobytes.tokens import transfer_token
from brownie import accounts, project

from argobytes.cli.leverage_cyy3crv import atomic_enter, atomic_exit
from argobytes.contracts import load_contract


# @pytest.mark.skip(reason="crashes ganache")
@pytest.mark.require_network("mainnet-fork")
def test_atomic_scripts(
    argobytes_flash_clone,
    click_test_runner,
    exit_cyy3crv_action,
    monkeypatch,
    unlocked_binance,
):
    account = accounts[0]

    # TODO: use click args
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(account))

    dai = load_contract(exit_cyy3crv_action.DAI())
    usdc = load_contract(exit_cyy3crv_action.USDC())
    usdt = load_contract(exit_cyy3crv_action.USDT())
    threecrv = load_contract(exit_cyy3crv_action.THREE_CRV())
    y3crv = load_contract(exit_cyy3crv_action.Y_THREE_CRV())
    cyy3crv = load_contract(exit_cyy3crv_action.CY_Y_THREE_CRV())

    # borrow some tokens from binance
    transfer_token(unlocked_binance, accounts[0], dai, 10000)
    # transfer_token(unlocked_binance, accounts[0], usdc, 10000)
    # transfer_token(unlocked_binance, accounts[0], usdt, 10000)

    enter_result = click_test_runner(atomic_enter)

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
    transfer_token(
        unlocked_binance, exit_cyy3crv_action.THREE_CRV_POOL(), dai, 1000000
    )

    exit_result = click_test_runner(atomic_exit)

    assert exit_result.exit_code == 0

    # make sure balances are what we expect
    assert dai.balanceOf(argobytes_flash_clone) == 0
    assert dai.balanceOf(account) > 0
    assert usdc.balanceOf(argobytes_flash_clone) == 0
    assert usdc.balanceOf(account) == 0
    assert usdt.balanceOf(argobytes_flash_clone) == 0
    assert usdt.balanceOf(account) == 0
    assert threecrv.balanceOf(argobytes_flash_clone) == 0
    assert threecrv.balanceOf(account) > 0
    assert y3crv.balanceOf(argobytes_flash_clone) == 0
    assert y3crv.balanceOf(account) == 0
    assert cyy3crv.balanceOf(argobytes_flash_clone) == 0
    assert cyy3crv.balanceOf(account) == 0
