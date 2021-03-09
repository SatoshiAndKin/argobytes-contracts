import brownie
import pytest
from brownie import accounts, ZERO_ADDRESS
from brownie.test import given, strategy
from eth_utils import to_bytes
from hypothesis import settings


# TODO: test access for all the functions!
def test_argobytes_arbitrage_access_control(argobytes_multicall, argobytes_proxy, argobytes_trader, example_action):
    value = 1

    borrows = []
    actions = [
        (
            example_action,
            0,
            example_action.sweep.encode_input(ZERO_ADDRESS, ZERO_ADDRESS, 0),
        )
    ]

    argobytes_trader_calldata = argobytes_trader.atomicArbitrage.encode_input(
        ZERO_ADDRESS, False, accounts[0], borrows, argobytes_multicall, actions,
    )

    assert(argobytes_proxy.owner() == accounts[0])

    # check that accounts[0] is allowed
    argobytes_proxy.execute(
        argobytes_trader.address,
        argobytes_trader_calldata,
        {"from": accounts[0]}
    )

    # check that accounts[1] is NOT allowed
    # TODO: this used to revert with "ArgobytesProxy: 403" but we don't bother checking authority before calling anymore to save gas
    with brownie.reverts(""):
        argobytes_proxy.execute(
            argobytes_trader.address,
            argobytes_trader_calldata,
            {"from": accounts[1]}
        )

    # TODO: set authority

    # TODO: check revert message if accounts[1] tries to call something

    # TODO: authorize accounts[1]

    # TODO: check that accounts[1] is allowed


def test_simple_execute(argobytes_multicall, argobytes_trader, argobytes_proxy, example_action):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    starting_balance = accounts[0].balance()

    borrows = []
    actions = [
        # call the sweep contract when its empty
        (
            example_action,
            1,
            example_action.sweep.encode_input(accounts[0], ZERO_ADDRESS, 0),
        )
    ]

    atomic_arbitrage_tx = argobytes_proxy.execute(
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            ZERO_ADDRESS,
            False,
            accounts[0],
            borrows,
            argobytes_multicall,
            actions,
        ),
        {
            "value": value,
            "gasPrice": 0,
        }
    )

    assert argobytes_proxy.balance() == 0
    assert accounts[0].balance() == starting_balance

    # TODO: check event logs to know profits
