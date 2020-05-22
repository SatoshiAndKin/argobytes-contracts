import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
# TODO: they use 0xEeE..., but our wrapper handles the conversion
zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(dai_erc20, kyber_action, usdc_erc20, weth9_erc20):
    eth_amount = 1e18
    dai_amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b)
    amounts = kyber_action.getAmounts(zero_address, eth_amount, dai_erc20)

    print("amounts 1", amounts)

    # TODO: use amounts from the previous call
    amounts = kyber_action.getAmounts(dai_erc20, dai_amount, zero_address)

    print("amounts 2", amounts)

    # TODO: what should we assert?


def test_action(kyber_action, dai_erc20, usdc_erc20):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(kyber_action, value)

    # make sure balances match what we expect
    assert kyber_action.balance() == value

    # trade ETH to USDC
    # tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    kyber_action.tradeEtherToToken(kyber_action, usdc_erc20, 1, 0, "")

    # TODO: check gas cost to make sure there are no regressions! (do this for all our tests!)
    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    kyber_action.tradeTokenToToken(kyber_action, usdc_erc20, dai_erc20, 1, 0, "")

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    kyber_action.tradeTokenToEther(zero_address, dai_erc20, 1, 0, "")

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero for accounts[0]
