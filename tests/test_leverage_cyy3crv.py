import pytest

from brownie import accounts, project

@pytest.mark.require_network("mainnet-fork")
def test_scripts(enter_cyy3crv_action, exit_cyy3crv_action, monkeypatch):
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(accounts[0]))

    # TODO: borrow some DAI from binance

    project.scripts.run("scripts/leverage_cyy3crv/enter")

    # TODO: make sure we can't get liquidated

    # TODO: make some trades so that 3pool increases in value

    project.scripts.run("scripts/leverage_cyy3crv/exit")

    # TODO: make sure we made a profit
