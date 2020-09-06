import brownie
import pytest
import warnings
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/611")
def test_kyber_arbitrage(address_zero, argobytes_atomic_actions, dai_erc20, argobytes_diamond, kyber_network_proxy, kyber_action, usdc_erc20):
    assert argobytes_diamond.balance() == 0
    assert kyber_action.balance() == 0

    value = 1e18

    # send some ETH into the vault
    accounts[0].transfer(argobytes_diamond, value)
    # send some ETH to the action to simulate arbitrage profits
    accounts[0].transfer(kyber_action, value)

    # make sure balances match what we expect
    assert argobytes_diamond.balance() == value
    assert kyber_action.balance() == value

    actions = [
        # trade ETH to USDC
        (
            kyber_action,
            kyber_action.tradeEtherToToken.encode_input(kyber_network_proxy, kyber_action, usdc_erc20, 1, 0),
            True
        ),
        # trade USDC to DAI
        (
            kyber_action,
            kyber_action.tradeTokenToToken.encode_input(kyber_network_proxy, kyber_action, usdc_erc20, dai_erc20, 1, 0),
            False

        ),
        # trade DAI to ETH
        (
            kyber_action,
            kyber_action.tradeTokenToEther.encode_input(kyber_network_proxy, address_zero, dai_erc20, 1, 0),
            False
        ),
    ]

    arbitrage_tx = argobytes_diamond.atomicArbitrage(
        address_zero, argobytes_atomic_actions, address_zero, [address_zero], value, actions, {'from': accounts[1]})

    assert argobytes_diamond.balance() > value

    # TODO: https://github.com/trufflesuite/ganache-core/issues/611
    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1
    # TODO: fetching this is crashing ganache
    # assert arbitrage_tx.return_value is not None

    # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
    # assert arbitrage_tx.return_value > 0

    # TODO: should we compare this to running without burning gas token?
    print("gas_used_with_gastoken: ", arbitrage_tx.gas_used)

    # TODO: make sure we didn't use all the gas token
