import pytest

from argobytes.tokens import transfer_token
from brownie import accounts, project

from argobytes.cli.leverage_cyy3crv import atomic_enter, atomic_exit
from argobytes.contracts import load_contract


# @pytest.mark.skip(reason="crashes ganache")
@pytest.mark.require_network("mainnet-fork")
@pytest.mark.no_call_coverage
def test_atomic_scripts(click_test_runner, dai_erc20, monkeypatch, unlocked_binance, usdc_erc20, exit_cyy3crv_action):
    monkeypatch.setenv("LEVERAGE_ACCOUNT", str(accounts[0]))

    # borrow some tokens from binance
    transfer_token(unlocked_binance, accounts[0], dai_erc20, 10000)
    # transfer_token(unlocked_binance, accounts[0], usdc_erc20, 10000)
    # TODO: usdt_erc20
    # transfer_token(unlocked_binance, accounts[0], usdt_erc20, 10000)

    result = click_test_runner(atomic_enter)

    assert result.exit_code == 0

    # TODO: make sure we can't get liquidated

    # simulate some trades so that 3pool increases in value
    # TODO: make some actual trades? 
    # TODO: how much DAI actually needs to be added to the pool
    transfer_token(unlocked_binance, exit_cyy3crv_action.THREE_CRV_POOL(), dai_erc20, 1000000)

    result = click_test_runner(atomic_exit)
    
    assert result.exit_code == 0

    # TODO: make sure we made a profit

