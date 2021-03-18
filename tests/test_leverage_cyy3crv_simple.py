import pytest

from argobytes.tokens import transfer_token
from brownie import accounts, project
from click.testing import CliRunner

from argobytes.cli.leverage_cyy3crv import simple_enter, simple_exit

@pytest.mark.require_network("mainnet-fork")
def test_simple_scripts(dai_erc20, monkeypatch, unlocked_binance, usdc_erc20):
    runner = CliRunner()

    account = accounts[0]

    # TODO: use flags instead of env?
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(account))

    # borrow some tokens from binance
    transfer_token(unlocked_binance, account, dai_erc20, 10000)
    # transfer_token(unlocked_binance, account, usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(unlocked_binance, account, usdt_erc20, 10000)

    result = runner.invoke(simple_enter)
    assert result.exit_code == 0

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    result = runner.invoke(simple_exit)
    assert result.exit_code == 0

    # TODO: make sure we made a profit
    raise NotImplementedError("wip")
