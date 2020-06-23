import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


def test_access_control(address_zero, example_action, argobytes_atomic_trade, argobytes_owned_vault):
    value = 1

    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)

    # encode a simple action that only sweeps funds
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(address_zero, address_zero, 0)],
        [True],
    )
    print("encoded_actions: ", encoded_actions)

    with brownie.reverts("ArgobytesOwnedVault.atomicArbitrage: Caller is not a trusted arbitrager"):
        argobytes_owned_vault.atomicArbitrage(
            address_zero, address_zero, address_zero, [address_zero], value, encoded_actions, {'from': accounts[0]})


def test_simple_borrow_and_sweep(address_zero, argobytes_atomic_trade, argobytes_owned_vault, example_action, kollateral_invoker):
    value = 1

    # make sure the arbitrage contract has no funds
    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)

    # TODO: i don't like having to encode lke this
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(address_zero, address_zero, 0)],
        [True],
    )

    # accounts[1] is setup as the default trusted bot
    atomic_arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        address_zero,
        argobytes_atomic_trade,
        kollateral_invoker,
        [address_zero],
        value,
        encoded_actions,
        {'from': accounts[1]},
    )

    profit = atomic_arbitrage_tx.return_value

    ending_balance = argobytes_owned_vault.balance()

    assert ending_balance == value
    assert profit == 0


def test_profitless_kollateral_fails(address_zero, argobytes_atomic_trade, argobytes_owned_vault, example_action, kollateral_invoker):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # no actual arb. just call the sweep contract
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(address_zero, address_zero, 0)],
        [True]
    )

    # accounts[1] is setup as the default trusted bot
    with brownie.reverts("ExternalCaller: insufficient ether balance"):
        argobytes_owned_vault.atomicArbitrage(
            address_zero, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})


def test_simple_kollateral(address_zero, argobytes_atomic_trade, argobytes_owned_vault, example_action, example_action_2, kollateral_invoker):
    value = 1e18

    # make sure the arbitrage contract has no funds
    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # add a giant arb return to the sweep contract
    accounts[0].transfer(example_action, value * 2)

    encoded_actions = argobytes_atomic_trade.encodeActions(
        [
            example_action,
            example_action_2,
            example_action,
        ],
        [
            example_action.sweep.encode_input(example_action_2, address_zero, 0),
            example_action_2.sweep.encode_input(example_action, address_zero, 0),
            example_action.sweep.encode_input(address_zero, address_zero, 0),
        ],
        [True, False, False],
    )

    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        address_zero, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})

    # TODO: what is the actual amount? it needs to include fees from kollateral
    assert arbitrage_tx.return_value > 0


def test_liquidgastoken_saves_gas(address_zero, argobytes_atomic_trade, argobytes_owned_vault, example_action, example_action_2, liquidgastoken, kollateral_invoker):
    value = 1e18

    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # make sure balances match what we expect
    assert argobytes_owned_vault.balance() == value
    assert example_action.balance() == value

    # sweep a bunch of times to use up gas
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [
            example_action,
            example_action_2,
            example_action,
        ],
        [
            example_action.sweep.encode_input(example_action_2, address_zero, 0),
            example_action_2.sweep.encode_input(example_action, address_zero, 0),
            example_action.sweep.encode_input(address_zero, address_zero, 0),
        ],
        [True, False, False],
    )

    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        address_zero, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})

    # make sure balances match what we expect
    assert arbitrage_tx.return_value == value
    assert argobytes_owned_vault.balance() == 2 * value

    gas_used_without_gastoken = arbitrage_tx.gas_used

    print("gas_used_without_gastoken: ", gas_used_without_gastoken)

    # move the ETH arb return back to the sweep contract
    argobytes_owned_vault.withdrawTo(address_zero, address_zero, example_action, value, {'from': accounts[0]})

    # make sure balances match what we expect
    assert argobytes_owned_vault.balance() == value
    assert example_action.balance() == value

    # mint some gas token
    # TODO: check the liquidgastoken price
    # TODO: how much should we make?
    # TODO: should we mintToSell to make it cheaper?
    liquidgastoken.mintToLiquidity(150, 0, 999999999999999, accounts[0], {'from': accounts[0], 'value': 1e19})
    # liquidgastoken.mintFor(100, argobytes_owned_vault, {'from': accounts[0]})

    # do the faked arbitrage trade again (but this time with gas tokens)
    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        liquidgastoken, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {
            'from': accounts[1],
            'gas_price': 150 * 1e9,
        })

    gas_used_with_gastoken = arbitrage_tx.gas_used

    print("gas_used_with_gastoken: ", gas_used_with_gastoken)

    # TODO: figure out the cost of gas tokens
    # TODO: value should actually be value - cost of gastokens that we bought and freed
    assert arbitrage_tx.return_value > value * 0.9995
    # assert argobytes_owned_vault.balance() == 2 * value
    assert argobytes_owned_vault.balance() > 1.9995 * value
    assert gas_used_with_gastoken < gas_used_without_gastoken
    # TODO: checking the gas used isn't enough. we need to check that the overall gas cost was less, too
    # TODO: assert something about the number of freed gas tokens. i don't think we are getting optimal amounts
