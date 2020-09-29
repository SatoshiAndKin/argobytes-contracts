import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from eth_abi import decode_single
from eth_utils import to_bytes
from hypothesis import settings


# TODO: test access for all the functions!
def test_argobytes_arbitrage_access_control(address_zero, argobytes_actor, argobytes_proxy, argobytes_trader, example_action):
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
    argobytes_proxy.execute(
        argobytes_trader.address,
        argobytes_trader_calldata,
        {"from": accounts[0]}
    )

    # check that accounts[1] is NOT allowed
    with brownie.reverts("ArgobytesAuth: 403"):
        argobytes_proxy.execute(
            argobytes_trader.address,
            argobytes_trader_calldata,
            {"from": accounts[1]}
        )

    # TODO: approve accounts[1]
    # assert False

    # TODO: check that accounts[1] is allowed
    # assert False


def test_simple_sweep(address_zero, argobytes_actor, argobytes_trader, argobytes_proxy, example_action, kollateral_invoker):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_proxy.balance() == 0
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

    atomic_arbitrage_tx = argobytes_proxy.execute(
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

    assert argobytes_proxy.balance() == 0
    assert accounts[0].balance() == starting_balance
    assert profit == 0


@pytest.mark.skip(reason="Refactor removed kollateral. need to rethink adding it again")
def test_simple_kollateral(address_zero, argobytes_trader, argobytes_proxy, example_action, example_action_2, kollateral_invoker):
    assert False
