from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
def test_uniswap_actions(uniswap_action):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(uniswap_action, value)

    # make sure balances match what we expect
    assert uniswap_action.balance() == value

    dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

    # trade ETH to USDC
    # tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    uniswap_action.tradeEtherToToken(uniswap_action, usdc, 1, 0, "")

    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    uniswap_action.tradeTokenToToken(uniswap_action, usdc, dai, 1, 0, "")

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    uniswap_action.tradeTokenToEther(accounts[0], dai, 1, 0, "")

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero
