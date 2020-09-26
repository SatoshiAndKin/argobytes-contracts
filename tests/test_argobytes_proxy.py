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
            True,
        )
    ]

    argobytes_trader_calldata = argobytes_trader.atomicArbitrage.encode_input(
        borrows, argobytes_actor, actions,
    )

    # # check that accounts[0] is allowed
    # argobytes_proxy.execute(
    #     False,
    #     False,
    #     argobytes_trader.address,
    #     argobytes_trader_calldata,
    #     {"from": accounts[0], "value": value}
    # )

    # check that accounts[1] is NOT allowed
    with brownie.reverts("ArgobytesAuth: 403"):
        argobytes_proxy.execute(
            False,
            False,
            argobytes_trader.address,
            argobytes_trader_calldata,
            {"from": accounts[1], "value": value}
        )

    # TODO: approve accounts[1]
    # TODO: check that accounts[1] is allowed


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
            example_action.sweep.encode_input(address_zero, address_zero, 0),
            True,
        )
    ]

    atomic_arbitrage_tx = argobytes_proxy.execute(
        False,
        False,
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
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
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    # add a fake "arb return" to the sweep contract
    accounts[0].transfer(example_action, value)

    borrows = []
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(address_zero, address_zero, 0),
            True,
        ),
    ]

    arbitrage_tx = argobytes_proxy.execute(
        False,
        False,
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            borrows, argobytes_actor, actions
        ),
    )

    profit = decode_single('uint256', arbitrage_tx.return_value)

    # TODO: what is the actual amount? it needs to include fees from kollateral
    assert profit > 0


def test_liquidgastoken_saves_gas(address_zero, argobytes_actor, argobytes_trader, argobytes_proxy, example_action, liquidgastoken):
    value = 1e18
    gas_price = 150 * 1e9  # 150 gwei

    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    starting_balance = accounts[0].balance()

    # make sure balances match what we expect
    assert starting_balance > value
    assert example_action.balance() == value

    borrows = []

    # sweep and use up gas
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(address_zero, address_zero, 100000),
            True,
        ),
    ]

    # execute without freeing gas token
    arbitrage_tx = argobytes_proxy.execute(
        False,
        False,
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            borrows, argobytes_actor, actions
        ),
        {
            # 'gas_price': gas_price,
            "value": value,
        }
    )

    profit = decode_single('uint256', arbitrage_tx.return_value)

    # make sure balances match what we expect
    assert profit == value
    assert argobytes_proxy.balance() == 0
    assert accounts[0].balance() == starting_balance + value

    gas_used_without_gastoken = arbitrage_tx.gas_used

    print("gas_used_without_gastoken: ", gas_used_without_gastoken)

    # move the ETH arb return back to the sweep contract
    argobytes_proxy.adminCall(address_zero, example_action, to_bytes(hexstr="0x"), value, {'from': accounts[0]})

    assert argobytes_proxy.balance() == value
    assert example_action.balance() == value

    # mint and approve some gas token
    # TODO: how much should we make?
    liquidgastoken.mint(100)
    liquidgastoken.approve(argobytes_proxy, 100)

    # do the faked arbitrage trade again (but this time with gas tokens)
    arbitrage_tx = argobytes_proxy.execute(
        True,
        True,
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            borrows,
            argobytes_actor,
            actions,
        ),
        {
            'gas_price': gas_price,
            'value': value,
        }
    )

    gas_used_with_gastoken = arbitrage_tx.gas_used

    print("gas_used_with_gastoken: ", gas_used_with_gastoken)

    profit = decode_single('uint256', arbitrage_tx.return_value)

    # TODO: figure out the cost of gas tokens
    # TODO: value should actually be value - cost of gastokens that we bought and freed
    assert profit > value * 0.9995
    # assert argobytes_proxy.balance() == 2 * value
    assert argobytes_proxy.balance() > 1.9995 * value
    assert gas_used_with_gastoken < gas_used_without_gastoken
    # TODO: checking the gas used isn't enough. we need to check that the overall gas cost was less, too
    # TODO: assert something about the number of freed gas tokens. i don't think we are getting optimal amounts
