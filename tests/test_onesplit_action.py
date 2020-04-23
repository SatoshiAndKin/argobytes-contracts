# TODO: max_examples should not be 1, but tests are slow with the default while developing

import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
zero_address = "0x0000000000000000000000000000000000000000"

# TODO: parameterize with a bunch of mainnet token addresses


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
def test_onesplit_actions(onesplit_action):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(onesplit_action, value)

    # make sure balances match what we expect
    assert onesplit_action.balance() == value

    # TODO: use dai_erc20 and usdc_erc20 fixtures
    dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

    parts = 1
    disable_flags = 0

    extra_data = onesplit_action.encodeExtraData(parts, disable_flags)

    print("extra_data: ", extra_data)

    # trade ETH to USDC
    # tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    onesplit_action.tradeEtherToToken(onesplit_action, usdc, 1, 0, extra_data)

    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    onesplit_action.tradeTokenToToken(
        onesplit_action, usdc, dai, 1, 0, extra_data)

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    onesplit_action.tradeTokenToEther(accounts[0], dai, 1, 0, extra_data)

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero
