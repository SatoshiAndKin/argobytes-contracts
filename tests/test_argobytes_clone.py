import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from eth_abi import decode_single
from eth_utils import to_bytes
from hypothesis import settings


# TODO: test access for all the functions!
def test_argobytes_arbitrage_access_control(address_zero, argobytes_actor, argobytes_clone, argobytes_trader, example_action):
    value = 1

    borrows = []
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(address_zero, address_zero, 0),
            False,
        )
    ]

    argobytes_trader_calldata = argobytes_trader.atomicArbitrage.encode_input(
        address_zero, False, accounts[0], borrows, argobytes_actor, actions,
    )

    # check that accounts[0] is allowed
    argobytes_clone.execute(
        argobytes_trader.address,
        argobytes_trader_calldata,
        {"from": accounts[0]}
    )

    # check that accounts[1] is NOT allowed
    # TODO: this used to revert with "ArgobytesAuth: 403" but we don't bother checking authority before calling anymore to save gas
    with brownie.reverts(""):
        argobytes_clone.execute(
            argobytes_trader.address,
            argobytes_trader_calldata,
            {"from": accounts[1]}
        )

    # TODO: set authority

    # TODO: check revert message if accounts[1] tries to call something

    # TODO: authorize accounts[1]

    # TODO: check that accounts[1] is allowed


def test_simple_sweep(address_zero, argobytes_actor, argobytes_trader, argobytes_clone, example_action):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_clone.balance() == 0
    assert example_action.balance() == 0

    starting_balance = accounts[0].balance()

    borrows = []
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(accounts[0], address_zero, 0),
            True,
        )
    ]

    atomic_arbitrage_tx = argobytes_clone.execute(
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            address_zero,
            False,
            accounts[0],
            borrows,
            argobytes_actor,
            actions,
        ),
        {
            "value": value,
            "gasPrice": 0,
        }
    )

    profit = decode_single('uint256', atomic_arbitrage_tx.return_value)

    assert argobytes_clone.balance() == 0
    assert accounts[0].balance() == starting_balance
    assert profit == 0
