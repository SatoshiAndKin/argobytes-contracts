import brownie
import pytest
import warnings
from brownie import accounts, ZERO_ADDRESS
from brownie.test import given, strategy
from hypothesis import settings


def test_liquidgastoken_saves_gas(argobytes_multicall, argobytes_trader, example_action, liquidgastoken):
    value = 1e18

    borrows = []
    actions = [
        (
            example_action,
            1,
            example_action.sweep.encode_input(accounts[0], ZERO_ADDRESS, 400000),
        )
    ]

    # do it once without lgt
    atomic_arbitrage_tx = argobytes_trader.atomicArbitrage(
        False,
        False,
        accounts[0],
        borrows,
        argobytes_multicall,
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
        argobytes_multicall,
        actions,
        {
            "gasPrice": 300,
        }
    )

    assert atomic_arbitrage_lgt_tx.gas_used < atomic_arbitrage_tx.gas_used


def test_simple_arbitrage(argobytes_multicall, argobytes_trader, example_action, weth9_erc20):
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
            0,
            example_action.sweep.encode_input(accounts[0], weth9_erc20, 0),
        ),
    ]

    arbitrage_tx = argobytes_trader.atomicArbitrage(
        False, False, accounts[0], borrows, argobytes_multicall, actions
    )

    assert weth9_erc20.balanceOf(example_action) == 0
    assert weth9_erc20.balanceOf(argobytes_trader) == 0
    assert weth9_erc20.balanceOf(argobytes_multicall) == 0
    assert weth9_erc20.balanceOf(accounts[0]) == 2 * value

    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1

    # TODO: check logs for profits


def test_simple_dydx_flashloan():
    assert False


def test_simple_atomic_trade():
    assert False


def test_check_balance():
    assert False


def test_check_erc20_balance():
    assert False
