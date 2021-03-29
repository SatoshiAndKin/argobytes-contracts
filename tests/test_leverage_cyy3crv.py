import pytest

from argobytes.tokens import transfer_token
from brownie import accounts, project
from click.testing import CliRunner

from argobytes.cli.leverage_cyy3crv import atomic_enter, atomic_exit


# @pytest.mark.skip(reason="crashes ganache")
@pytest.mark.require_network("mainnet-fork")
@pytest.mark.no_call_coverage
def test_atomic_scripts(dai_erc20, monkeypatch, unlocked_binance, usdc_erc20):
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(accounts[0]))

    # borrow some tokens from binance
    transfer_token(unlocked_binance, accounts[0], dai_erc20, 10000)
    # transfer_token(unlocked_binance, accounts[0], usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(unlocked_binance, accounts[0], usdt_erc20, 10000)

    runner = CliRunner()

    print("running atomic_enter...")
    result = runner.invoke(atomic_enter, catch_exceptions=False)
    print(result)

    assert result.exit_code == 0

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    print("running atomic_exit...")
    result = runner.invoke(atomic_exit, catch_exceptions=False)
    print(result)
    # print(result.stdout)
    # print(result.stderr)
    assert result.exit_code == 0

    # TODO: make sure we made a profit
