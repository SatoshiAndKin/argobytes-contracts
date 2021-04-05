import brownie
import pytest
from brownie import ZERO_ADDRESS, accounts
from brownie.test import given, strategy
from hypothesis import settings


def test_simple_arbitrage(
    argobytes_multicall, argobytes_trader, example_action, weth9_erc20
):
    value = 1e18

    # get some WETH for accounts[1]
    weth9_erc20.deposit({"value": 2 * value, "from": accounts[1]})

    # send some WETH to accounts[0]
    weth9_erc20.transfer(accounts[0], value, {"from": accounts[1]})

    # allow the proxy to use account[0]'s WETH
    weth9_erc20.approve(argobytes_trader, value, {"from": accounts[0]})

    # send some ETH to the action to simulate arbitrage profits
    weth9_erc20.transfer(example_action, value, {"from": accounts[1]})

    # make sure balances match what we expect
    assert weth9_erc20.balanceOf(accounts[0]) == value
    assert weth9_erc20.balanceOf(example_action) == value

    borrows = [
        # 1 WETH from accounts[0] to example_action
        (value, weth9_erc20, example_action,),
    ]

    # NOTE! Multicall actions do not have CallType! That is just our proxy actions! maybe need different names?
    actions = [
        # sweep WETH
        (
            example_action,
            False,
            example_action.sweep.encode_input(accounts[0], weth9_erc20, 0),
        ),
    ]

    arbitrage_tx = argobytes_trader.atomicArbitrage(
        accounts[0], borrows, argobytes_multicall, actions
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
