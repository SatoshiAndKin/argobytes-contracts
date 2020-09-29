import brownie
import pytest
import warnings
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# TODO: test atomicTrade

# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/611")
def test_simple_arbitrage(address_zero, argobytes_actor, argobytes_trader, example_action, weth9_erc20):
    value = 1e18

    # get some WETH
    weth9_erc20.deposit({"value": 2 * value})

    # send some WETH to accounts[0]
    weth9_erc20.transfer(accounts[0], value)

    # allow the proxy to use account[0]'s WETH
    weth9_erc20.approve(argobytes_trader, value, {"from": accounts[0]})

    # send some ETH to the action to simulate arbitrage profits
    weth9_erc20.transfer(example_action, value)

    # make sure balances match what we expect
    assert weth9_erc20.balanceOf(accounts[0]) == value
    assert weth9_erc20.balanceOf(example_action) == value

    borrows = [
        # 1 WETH from accounts[0] to example_action
        (
            weth9_erc20,
            value,
            example_action,
        ),
    ]

    actions = [
        # sweep WETH
        (
            example_action,
            example_action.sweep.encode_input(accounts[0], weth9_erc20, 0),
            False
        ),
    ]

    arbitrage_tx = argobytes_trader.atomicArbitrage(
        False, False, accounts[0], borrows, argobytes_actor, actions
    )

    assert weth9_erc20.balanceOf(example_action) == 0
    assert weth9_erc20.balanceOf(argobytes_trader) == 0
    assert weth9_erc20.balanceOf(argobytes_actor) == 0
    assert weth9_erc20.balanceOf(accounts[0]) == 2 * value

    # TODO: https://github.com/trufflesuite/ganache-core/issues/611
    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1
    # TODO: fetching this is crashing ganache
    # assert arbitrage_tx.return_value is not None

    # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
    # assert arbitrage_tx.return_value > 0


def test_liquidgastoken_saves_gas(address_zero, argobytes_actor, argobytes_trader, example_action, liquidgastoken):
    value = 1e18

    borrows = []
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(accounts[0], address_zero, 1000000),
            True,
        )
    ]

    # do it once without lgt
    atomic_arbitrage_tx = argobytes_trader.atomicArbitrage(
        False,
        False,
        accounts[0],
        borrows,
        argobytes_actor,
        actions,
        {
            "gasPrice": 300,
        }
    )

    # Now do it again with liquid gas token
    liquidgastoken.mint(100, {"from": accounts[0]})
    liquidgastoken.approve(argobytes_trader, 100, {"from": accounts[0]})

    atomic_arbitrage_lgt_tx = argobytes_trader.atomicArbitrage(
        True,
        True,
        accounts[0],
        borrows,
        argobytes_actor,
        actions,
        {
            "gasPrice": 300,
        }
    )

    assert atomic_arbitrage_lgt_tx.gas_used < atomic_arbitrage_tx.gas_used
