from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie


def test_get_amounts(address_zero, dai_erc20, uniswap_v1_factory, uniswap_v1_action, usdc_erc20, weth9_erc20):
    eth_amount = 1e18
    dai_amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a problem decoding their return_value!
    amounts = uniswap_v1_action.getAmounts(address_zero, eth_amount, dai_erc20, uniswap_v1_factory)

    print("amounts 1", amounts)
    # TODO: what should we assert?

    # TODO: use amounts from the previous call
    amounts = uniswap_v1_action.getAmounts(dai_erc20, dai_amount, address_zero, uniswap_v1_factory)

    print("amounts 2", amounts)
    # TODO: key access doesn't work yet. hopefully in 1.8.6
    # assert(amounts[0]["taker_token"] == dai_erc20)
    # assert(amounts[0]["maker_token"] == address_zero)
    # assert(amounts[0]["taker_wei"] == dai_amount)
    # assert(amounts[0]["maker_wei"] > 0)
    # TODO: what should we assert?


def test_get_exchange_weth9(address_zero, uniswap_v1_factory, uniswap_v1_action, weth9_erc20):
    exchange = uniswap_v1_action.getExchange.call(uniswap_v1_factory, weth9_erc20)
    print("exchange:", exchange)

    assert exchange != address_zero


def test_get_exchange_failure(address_zero, uniswap_v1_factory, uniswap_v1_action):
    exchange = uniswap_v1_action.getExchange.call(uniswap_v1_factory, address_zero)
    print("exchange:", exchange)

    assert exchange == address_zero


# @pytest.mark.xfail(reason="test passes when its run by itself, but it fails when everything is run together. bug in test isolation? bug in ganache-cli?")
def test_action(address_zero, uniswap_v1_factory, uniswap_v1_action, dai_erc20, usdc_erc20):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert uniswap_v1_action.balance() == value

    usdc_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, usdc_erc20)
    dai_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, dai_erc20)

    # trade ETH to USDC
    # tradeEtherToToken(address to, address exchange, address dest_token, uint256 dest_min_tokens, uint256 trade_gas)
    uniswap_v1_action.tradeEtherToToken(uniswap_v1_action, usdc_exchange, usdc_erc20, 1, 0)

    # make sure ETH balance on the action is zero (it will be swept back to accounts[0])
    assert uniswap_v1_action.balance() == 0

    # make sure USDC balance on the action is non-zero
    assert usdc_erc20.balanceOf(uniswap_v1_action) > 0

    # trade USDC to DAI
    # tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint256 dest_min_tokens, uint256 trade_gas)
    uniswap_v1_action.tradeTokenToToken(uniswap_v1_action, usdc_exchange, usdc_erc20, dai_erc20, 1, 0)

    # make sure USDC balance on the action is zero
    assert usdc_erc20.balanceOf(uniswap_v1_action) == 0

    # make sure DAI balance is non-zero
    assert dai_erc20.balanceOf(uniswap_v1_action) > 0

    # save ETH balance for accounts[0]
    starting_eth_balance = accounts[0].balance()

    # TODO: we really should test that setting "to" to address_zero sends to msg.sender on all of them

    # trade DAI to ETH
    # tradeTokenToEther(address payable to, address exchange, address src_token, uint256 dest_min_tokens, uint256 trade_gas)
    uniswap_v1_action.tradeTokenToEther(address_zero, dai_exchange, dai_erc20, 1, 0)

    # make sure DAI balance on the action is zero (i think it will be swept back to accounts[0])
    assert dai_erc20.balanceOf(uniswap_v1_action) == 0

    # make sure ETH balance increased for accounts[0]
    assert starting_eth_balance < accounts[0].balance()
