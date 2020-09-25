import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from eth_utils import to_bytes
from hypothesis import settings


# TODO: test access for all the functions!
def test_argobytes_arbitrage_access_control(address_zero, example_action, argobytes_proxy, argobytes_trader):
    value = 1

    # TODO: check that accounts[0] is allowed

    # TODO: check that accounts[1] is not allowed
    with brownie.reverts("ArgobytesProxy: 403"):
        argobytes_proxy.execute(
            argobytes_trader.address,
            argobytes_trader.atomicArbitrage.encode_input(
                address_zero, address_zero, address_zero, [address_zero], value, []
            ),
            {"from": accounts[1], "value": value}
        )

    # TODO: approve accounts[1]
    # TODO: check that accounts[1] is allowed


def test_admin_atomic_actions():
    assert False


def test_admin_delegate_call():
    assert False


def test_admin_grant_roles():
    assert False


def test_simple_borrow_and_sweep(address_zero, argobytes_trader, argobytes_proxy, example_action, kollateral_invoker):
    value = 1

    # make sure the arbitrage contract has no funds
    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the proxy
    accounts[0].transfer(argobytes_proxy, value)

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
            address_zero,
            argobytes_actor,
            kollateral_invoker,
            [address_zero],
            value,
            actions,
        ),
    )

    profit = atomic_arbitrage_tx.return_value

    ending_balance = argobytes_proxy.balance()

    assert ending_balance == value
    assert profit == 0


def test_profitless_kollateral_fails(address_zero, argobytes_trader, argobytes_proxy, example_action, kollateral_invoker):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    # no actual arb. just call the sweep contract
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(address_zero, address_zero, 0),
            True,
        )
    ]

    # accounts[1] is setup as the default trusted bot
    with brownie.reverts("ExternalCaller: insufficient ether balance"):
        argobytes_proxy.atomicArbitrage(
            address_zero, argobytes_actor, kollateral_invoker, [address_zero], value, actions, {'from': accounts[1]})


def test_simple_kollateral(address_zero, argobytes_trader, argobytes_proxy, example_action, example_action_2, kollateral_invoker):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    # add a fake "arb return" to the sweep contract
    accounts[0].transfer(example_action, value * 2)

    actions = [
        (
            example_action,
            example_action.sweep.encode_input(address_zero, address_zero, 0),
            True,
        ),
    ]

    arbitrage_tx = argobytes_proxy.atomicArbitrage(
        address_zero, argobytes_actor, kollateral_invoker, [address_zero], value, actions, {'from': accounts[1]})

    # TODO: what is the actual amount? it needs to include fees from kollateral
    assert arbitrage_tx.return_value > 0


# TODO: test with WETH instead of ETH?
def test_liquidgastoken_saves_gas(address_zero, argobytes_trader, argobytes_proxy, example_action, example_action_2, liquidgastoken, kollateral_invoker):
    value = 1e18
    gas_price = 150 * 1e9  # 150 gwei

    assert argobytes_proxy.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_proxy, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # make sure balances match what we expect
    assert argobytes_proxy.balance() == value
    assert example_action.balance() == value

    # sweep and use up gas
    actions = [
        (
            example_action,
            example_action.sweep.encode_input(address_zero, address_zero, 100000),
            True,
        ),
    ]

    arbitrage_tx = argobytes_proxy.atomicArbitrage(
        address_zero, argobytes_actor, kollateral_invoker, [address_zero], value, actions, {
            'from': accounts[1],
            # 'gas_price': gas_price,
        })

    # make sure balances match what we expect
    assert arbitrage_tx.return_value == value
    assert argobytes_proxy.balance() == 2 * value

    gas_used_without_gastoken = arbitrage_tx.gas_used

    print("gas_used_without_gastoken: ", gas_used_without_gastoken)

    # move the ETH arb return back to the sweep contract
    argobytes_proxy.adminCall(address_zero, example_action, to_bytes(hexstr="0x"), value, {'from': accounts[0]})

    assert argobytes_proxy.balance() == value
    assert example_action.balance() == value

    # mint and approve some gas token
    # TODO: how much should we make?
    liquidgastoken.mint(100)
    liquidgastoken.approve(argobytes_proxy, -1)

    # do the faked arbitrage trade again (but this time with gas tokens)
    arbitrage_tx = argobytes_proxy.execute(
        True,
        True,
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            argobytes_actor,
            kollateral_invoker,
            [address_zero],
            value,
            actions,
        ),
        {
            'gas_price': gas_price,
            "value": "1 ether",
        }
    )

    gas_used_with_gastoken = arbitrage_tx.gas_used

    print("gas_used_with_gastoken: ", gas_used_with_gastoken)

    # TODO: figure out the cost of gas tokens
    # TODO: value should actually be value - cost of gastokens that we bought and freed
    assert arbitrage_tx.return_value > value * 0.9995
    # assert argobytes_proxy.balance() == 2 * value
    assert argobytes_proxy.balance() > 1.9995 * value
    assert gas_used_with_gastoken < gas_used_without_gastoken
    # TODO: checking the gas used isn't enough. we need to check that the overall gas cost was less, too
    # TODO: assert something about the number of freed gas tokens. i don't think we are getting optimal amounts
