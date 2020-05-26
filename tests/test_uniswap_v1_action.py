from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie

zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(dai_erc20, uniswap_factory, uniswap_v1_action, usdc_erc20, weth9_erc20):
    eth_amount = 1e18
    dai_amount = 1e20

    zero_address = "0x0000000000000000000000000000000000000000"

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a problem decoding their return_value!
    amounts = uniswap_v1_action.getAmounts(zero_address, eth_amount, dai_erc20, uniswap_factory)

    print("amounts 1", amounts)
    # TODO: what should we assert?

    # TODO: use amounts from the previous call
    amounts = uniswap_v1_action.getAmounts(dai_erc20, dai_amount, zero_address, uniswap_factory)

    print("amounts 2", amounts)
    # TODO: key access doesn't work yet. hopefully in 1.8.6
    # assert(amounts[0]["taker_token"] == dai_erc20)
    # assert(amounts[0]["maker_token"] == zero_address)
    # assert(amounts[0]["taker_wei"] == dai_amount)
    # assert(amounts[0]["maker_wei"] > 0)
    # TODO: what should we assert?


def test_action(uniswap_factory, uniswap_v1_action, dai_erc20, usdc_erc20):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert uniswap_v1_action.balance() == value

    usdc_exchange = uniswap_v1_action.getExchange(uniswap_factory, usdc_erc20)
    dai_exchange = uniswap_v1_action.getExchange(uniswap_factory, dai_erc20)

    # trade ETH to USDC
    # tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens, uint dest_max_tokens)
    uniswap_v1_action.tradeEtherToToken(uniswap_v1_action, usdc_exchange, usdc_erc20, 1, 0)

    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens)
    uniswap_v1_action.tradeTokenToToken(uniswap_v1_action, usdc_exchange, usdc_erc20, dai_erc20, 1, 0)

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # TODO: save ETH balance for accounts[0]
    # TODO: other tests need a similar change. we really should test zero_address sends to msg.sender on all of them

    # trade DAI to ETH
    # tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens, uint dest_max_tokens)
    uniswap_v1_action.tradeTokenToEther(zero_address, dai_exchange, dai_erc20, 1, 0)

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance increased for accounts[0]
