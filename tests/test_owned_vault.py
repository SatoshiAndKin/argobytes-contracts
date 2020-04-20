# TODO: max_examples should not be 1, but tests are slow with the default while developing

import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
zero_address = "0x0000000000000000000000000000000000000000"


@given(
    value=strategy('uint256', max_value=1e18, min_value=1),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_access_control(example_action, atomic_trade, owned_vault, value, fn_isolation):
    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)

    # encode a simple action that only sweeps funds
    encoded_actions = atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(zero_address)],
    )
    print("encoded_actions: ", encoded_actions)

    with brownie.reverts("ArgobytesOwnedVault.atomicArbitrage: Caller is not trusted"):
        owned_vault.atomicArbitrage(
            [zero_address], value, encoded_actions, {'from': accounts[0]})


@given(
    value=strategy('uint256', max_value=1e18, min_value=1),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_simple_borrow_and_sweep(value, atomic_trade, owned_vault, example_action, fn_isolation):
    # make sure the arbitrage contract has no funds
    assert owned_vault.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)

    # TODO: i don't like having to encode lke this
    encoded_actions = atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(zero_address)],
    )

    # accounts[1] is setup as the default trusted bot
    atomic_arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    profit = atomic_arbitrage_tx.return_value

    ending_balance = owned_vault.balance()

    assert ending_balance == value
    assert profit == 0


@given(
    value=strategy('uint256', max_value=1e18, min_value=1),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_profitless_kollateral_fails(atomic_trade, owned_vault, example_action, value, fn_isolation):
    # make sure the arbitrage contract has no funds
    assert owned_vault.balance() == 0

    # no actual arb. just call the sweep contract
    encoded_actions = atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(zero_address)],
    )

    # accounts[1] is setup as the default trusted bot
    # TODO: this is raising `KeyError: KeyError('0x91b01baeee3a24b590d112613814d86801005c7ef9353e7fc1eaeaf33ccf83b0',)`
    # https://etherscan.io/address/0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e
    # https://github.com/iamdefinitelyahuman/brownie/issues/430
    with brownie.reverts("ArgobytesAtomicTrade.execute: Not enough ETH balance to repay kollateral"):
        owned_vault.atomicArbitrage(
            [zero_address], value, encoded_actions, {'from': accounts[1]})


@given(
    value=strategy('uint256', max_value=1e18, min_value=1e8),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_simple_kollateral(atomic_trade, owned_vault, example_action, value, fn_isolation):
    # make sure the arbitrage contract has no funds
    assert owned_vault.balance() == 0

    # add a giant arb return to the sweep contract
    accounts[0].transfer(example_action, value * 2, gas_price=0)

    encoded_actions = atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(zero_address)],
    )

    arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    # TODO: what is the actual amount? it needs to include fees from kollateral
    assert arbitrage_tx.return_value > value


# TODO: i'm seeing a starting balance in owned_vault! i don't think fn_isolation and hypothesis strategies are working properly
@given(
    value=strategy('uint256', max_value=1e18, min_value=1e8),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_gastoken_saves_gas(atomic_trade, owned_vault, example_action, fn_isolation, value):
    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # make sure balances match what we expect
    assert owned_vault.balance() == value
    assert example_action.balance() == value

    # sweep a bunch of times to use up gas
    encoded_actions = atomic_trade.encodeActions(
        [example_action] * 12,
        [example_action.sweep.encode_input(zero_address)] * 12,
    )

    arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    # make sure balances match what we expect
    assert arbitrage_tx.return_value == value
    assert owned_vault.balance() == 2 * value

    gas_used_without_gastoken = arbitrage_tx.gas_used

    print("gas_used_without_gastoken: ", gas_used_without_gastoken)

    # move the arb return back to the sweep contract
    owned_vault.withdrawTo(zero_address, example_action, value)

    # make sure balances match what we expect
    assert owned_vault.balance() == value
    assert example_action.balance() == value

    # mint some gas token
    # TODO: how much should we make?
    owned_vault.mintGasToken()
    owned_vault.mintGasToken()
    owned_vault.mintGasToken()

    # TODO: use gastoken interface to get the number of gas tokens available

    # do the faked arbitrage trade again (but this time with gas tokens)
    arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    gas_used_with_gastoken = arbitrage_tx.gas_used

    print("gas_used_with_gastoken: ", gas_used_with_gastoken)

    assert arbitrage_tx.return_value == value
    assert owned_vault.balance() == 2 * value
    assert gas_used_with_gastoken < gas_used_without_gastoken
    # TODO: assert something about the number of freed gas tokens
