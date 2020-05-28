import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
address_zero = "0x0000000000000000000000000000000000000000"


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1),
# )
def test_access_control(example_action, argobytes_atomic_trade, argobytes_owned_vault):
    value = 1

    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)

    # encode a simple action that only sweeps funds
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(address_zero, address_zero)],
    )
    print("encoded_actions: ", encoded_actions)

    with brownie.reverts("ArgobytesOwnedVault.atomicArbitrage: Caller is not trusted"):
        argobytes_owned_vault.atomicArbitrage(
            address_zero, address_zero, address_zero, [address_zero], value, encoded_actions, {'from': accounts[0]})


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1),
# )
def test_simple_borrow_and_sweep(argobytes_atomic_trade, argobytes_owned_vault, example_action, gastoken, kollateral_invoker):
    value = 1

    # make sure the arbitrage contract has no funds
    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)

    # TODO: i don't like having to encode lke this
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(address_zero, address_zero)],
    )

    # accounts[1] is setup as the default trusted bot
    atomic_arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        gastoken,
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


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1),
# )
def test_profitless_kollateral_fails(argobytes_atomic_trade, argobytes_owned_vault, example_action, gastoken, kollateral_invoker):
    value = 1

    # make sure the arbitrage contract has no funds
    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # no actual arb. just call the sweep contract
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(address_zero, address_zero)],
    )

    # accounts[1] is setup as the default trusted bot
    # TODO: this is raising `KeyError: KeyError('0x91b01baeee3a24b590d112613814d86801005c7ef9353e7fc1eaeaf33ccf83b0',)`
    # https://etherscan.io/address/0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e
    # https://github.com/iamdefinitelyahuman/brownie/issues/430
    with brownie.reverts("ArgobytesAtomicTrade.execute: Not enough ETH balance to repay kollateral"):
        argobytes_owned_vault.atomicArbitrage(
            gastoken, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
def test_simple_kollateral(argobytes_atomic_trade, argobytes_owned_vault, example_action, example_action_2, kollateral_invoker):
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
        ] * 5 + [example_action],
        [
            example_action.sweep.encode_input(example_action_2, address_zero),
            example_action_2.sweep.encode_input(example_action, address_zero)
        ] * 5 + [example_action.sweep.encode_input(address_zero, address_zero)],
    )

    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        address_zero, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})

    # TODO: what is the actual amount? it needs to include fees from kollateral
    assert arbitrage_tx.return_value > 0


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
# NOTE! ganache has
def test_gastoken_saves_gas(argobytes_atomic_trade, argobytes_owned_vault, example_action, example_action_2, gastoken, kollateral_invoker):
    value = 1e10

    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # make sure balances match what we expect
    assert argobytes_owned_vault.balance() == value
    assert example_action.balance() == value

    # mint some gas token
    # TODO: how much should we make?
    argobytes_owned_vault.mintGasToken(gastoken, 26, {'from': accounts[0]})
    argobytes_owned_vault.mintGasToken(gastoken, 26, {'from': accounts[0]})
    argobytes_owned_vault.mintGasToken(gastoken, 26, {'from': accounts[0]})

    # sweep a bunch of times to use up gas
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [
            example_action,
            example_action_2,
        ] * 5 + [example_action],
        [
            example_action.sweep.encode_input(example_action_2, address_zero),
            example_action_2.sweep.encode_input(example_action, address_zero)
        ] * 5 + [example_action.sweep.encode_input(address_zero, address_zero)],
    )

    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        address_zero, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})

    # make sure balances match what we expect
    assert arbitrage_tx.return_value == value
    assert argobytes_owned_vault.balance() == 2 * value

    gas_used_without_gastoken = arbitrage_tx.gas_used

    print("gas_used_without_gastoken: ", gas_used_without_gastoken)

    # move the arb return back to the sweep contract
    argobytes_owned_vault.withdrawTo(address_zero, example_action, value, {'from': accounts[0]})

    # make sure balances match what we expect
    assert argobytes_owned_vault.balance() == value
    assert example_action.balance() == value

    # TODO: use gastoken interface to get the number of gas tokens available

    # do the faked arbitrage trade again (but this time with gas tokens)
    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        gastoken, argobytes_atomic_trade, kollateral_invoker, [address_zero], value, encoded_actions, {'from': accounts[1]})

    gas_used_with_gastoken = arbitrage_tx.gas_used

    print("gas_used_with_gastoken: ", gas_used_with_gastoken)

    assert arbitrage_tx.return_value == value
    assert argobytes_owned_vault.balance() == 2 * value
    assert gas_used_with_gastoken < gas_used_without_gastoken
    # TODO: assert something about the number of freed gas tokens. i don't think we are getting optimal amounts
