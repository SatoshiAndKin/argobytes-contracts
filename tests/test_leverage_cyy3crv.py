import pytest

from argobytes.tokens import transfer_token
from brownie import accounts, project


@pytest.mark.skip(reason="crashes ganache")
@pytest.mark.require_network("mainnet-fork")
def test_atomic_scripts(dai_erc20, monkeypatch, unlocked_binance, usdc_erc20):
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(accounts[0]))

    # borrow some tokens from binance
    transfer_token(unlocked_binance, accounts[0], dai_erc20, 10000)
    # transfer_token(unlocked_binance, accounts[0], usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(unlocked_binance, accounts[0], usdt_erc20, 10000)

    project.scripts.run("scripts/leverage_cyy3crv/enter")

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    project.scripts.run("scripts/leverage_cyy3crv/exit")

    # TODO: make sure we made a profit
    raise NotImplementedError("wip")
