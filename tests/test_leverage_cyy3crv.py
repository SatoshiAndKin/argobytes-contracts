import pytest

from brownie import accounts, project

@pytest.mark.require_network("mainnet-fork")
def test_scripts(enter_cyy3crv, exit_cyy3crv, monkeypatch):
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(accounts[0]))
    monkeypatch.setenv("LEVERAGE_Y3CRV", str(leverage_y3crv.address))

    # TODO: borrow some DAI from binance

    project.scripts.run("scripts/enter")

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    project.scripts.run("scripts/exit")

    # TODO: make sure we made a profit
