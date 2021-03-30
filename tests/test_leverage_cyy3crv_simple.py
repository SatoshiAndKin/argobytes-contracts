import pytest

from argobytes.tokens import transfer_token
from brownie import accounts, project
from click.testing import CliRunner

from argobytes.cli.leverage_cyy3crv import simple_enter, simple_exit


@pytest.mark.require_network("mainnet-fork")
def test_simple_scripts(
    click_test_runner,
    dai_erc20,
    exit_cyy3crv_action,
    monkeypatch,
    unlocked_binance,
    usdc_erc20,
):
    account = accounts[0]

    # TODO: use flags instead of env?
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(account))

    # borrow some tokens from binance
    transfer_token(unlocked_binance, account, dai_erc20, 10000)
    # transfer_token(unlocked_binance, account, usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(unlocked_binance, account, usdt_erc20, 10000)

    result = click_test_runner(simple_enter)

    assert result.exit_code == 0

    # TODO: make sure we can't get liquidated

    # simulate some trades so that 3pool increases in value
    # TODO: make some actual trades?
    # TODO: how much DAI actually needs to be added to the pool
    transfer_token(
        unlocked_binance, exit_cyy3crv_action.THREE_CRV_POOL(), dai_erc20, 500000
    )

    # pretend like we made money somewhere else and can close our loan
    transfer_token(unlocked_binance, accountsa, dai_erc20, 100000)

    result = click_test_runner(simple_exit)

    assert result.exit_code == 0

    # TODO: make sure we made a profit
