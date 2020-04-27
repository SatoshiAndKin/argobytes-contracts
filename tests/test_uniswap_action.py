from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie


def test_get_amounts(dai_erc20, no_call_coverage, uniswap_action, usdc_erc20, weth9_erc20, skip_coverage):
    eth_amount = 1e18
    dai_amount = 1e20

    zero_address = "0x0000000000000000000000000000000000000000"

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    tx = uniswap_action.getAmounts(zero_address, eth_amount, dai_erc20)

    print("tx 1 gas", tx.gas_used)

    # TODO: use amounts from the previous call
    tx = uniswap_action.getAmounts(dai_erc20, dai_amount, zero_address)

    print("tx 2 gas", tx.gas_used)

    # TODO: what should we assert?


def test_action(uniswap_action):
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
