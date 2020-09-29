import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# TODO: coverage used to work here. why is it failing now? geth upgrade?
def test_get_amounts(address_zero, dai_erc20, kyber_action, kyber_network_proxy, usdc_erc20, weth9_erc20):
    eth_amount = 1e18
    dai_amount = 1e20

    # even though kyber uses it's own 0x0000eeee... address, we use the zero address for ETH

    # getAmounts(address token_a, uint token_a_amount, address token_b, address kyber_network_proxy)
    amounts = kyber_action.getAmounts(address_zero, eth_amount, dai_erc20, kyber_network_proxy)

    print("amounts 1", amounts)

    # TODO: use amounts from the previous call
    amounts = kyber_action.getAmounts(dai_erc20, dai_amount, address_zero, kyber_network_proxy)

    print("amounts 2", amounts)

    # TODO: what should we assert?


def test_action(address_zero, kyber_action, kyber_network_proxy, dai_erc20, usdc_erc20):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(kyber_action, value)

    # make sure balances match what we expect
    assert kyber_action.balance() == value

    # trade ETH to USDC
    # tradeEtherToToken()
    kyber_action.tradeEtherToToken(kyber_network_proxy, kyber_action, usdc_erc20, 1, 0)

    # TODO: check gas cost to make sure there are no regressions! (do this for all our tests!)
    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken()
    kyber_action.tradeTokenToToken(kyber_network_proxy, kyber_action, usdc_erc20, dai_erc20, 1, 0)

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # tradeTokenToEther()
    kyber_action.tradeTokenToEther(kyber_network_proxy, accounts[0], dai_erc20, 1, 0)

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero for accounts[0]
