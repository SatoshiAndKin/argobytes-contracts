import pytest

from argobytes_util import transfer_token
from brownie import accounts, project


@pytest.mark.require_network("mainnet-fork")
def test_simple_scripts(dai_erc20, monkeypatch, usdc_erc20):
    account = accounts[0]

    monkeypatch.setenv("LEVERAGE_ACCOUNT", account)

    # binance
    binance = accounts.at("0x85b931A32a0725Be14285B66f1a22178c672d69B", force=True)

    # borrow some tokens from binance
    transfer_token(binance, account, dai_erc20, 10000)
    # transfer_token(binance, account, usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(binance, account, usdt_erc20, 10000)

    project.scripts.run("scripts/leverage_cyy3crv/simple_enter")

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    project.scripts.run("scripts/leverage_cyy3crv/simple_exit")

    # TODO: make sure we made a profit


@pytest.mark.require_network("mainnet-fork")
def test_atomic_scripts(dai_erc20, monkeypatch, usdc_erc20):
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(accounts[0]))

    # binance
    binance = accounts.at("0x85b931A32a0725Be14285B66f1a22178c672d69B", force=True)

    # borrow some tokens from binance
    transfer_token(binance, accounts[0], dai_erc20, 10000)
    # transfer_token(binance, accounts[0], usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(binance, accounts[0], usdt_erc20, 10000)

    project.scripts.run("scripts/leverage_cyy3crv/enter")

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    project.scripts.run("scripts/leverage_cyy3crv/exit")

    # TODO: make sure we made a profit
