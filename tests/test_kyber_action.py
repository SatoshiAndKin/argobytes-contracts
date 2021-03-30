import brownie
import pytest
from brownie import accounts, ZERO_ADDRESS
from brownie.test import given, strategy
from eth_utils import to_bytes
from hypothesis import settings


# TODO: this test crashes ganache when we try to collect coverage
def test_action(
    kyber_action, kyber_network_proxy, dai_erc20, skip_coverage, usdc_erc20
):
    value = 1e17

    # TODO: build proper hints for the different trades
    hint = to_bytes(hexstr="0x")

    # send some ETH into the action
    accounts[0].transfer(kyber_action, value)

    # make sure balances match what we expect
    assert kyber_action.balance() == value

    # trade ETH to USDC
    # tradeEtherToToken()
    kyber_action.tradeEtherToToken(
        kyber_network_proxy, kyber_action, usdc_erc20, 1, hint
    )

    # TODO: check gas cost to make sure there are no regressions! (do this for all our tests!)
    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken()
    kyber_action.tradeTokenToToken(
        kyber_network_proxy, kyber_action, usdc_erc20, dai_erc20, 1, hint
    )

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # tradeTokenToEther()
    kyber_action.tradeTokenToEther(kyber_network_proxy, accounts[0], dai_erc20, 1, hint)

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero for accounts[0]
