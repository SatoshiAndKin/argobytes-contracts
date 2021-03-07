import brownie
import pytest
import warnings
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


def test_uniswap_arbitrage(address_zero, argobytes_actor, argobytes_clone, argobytes_trader, uniswap_v1_factory, uniswap_v1_action, usdc_erc20, dai_erc20):
    assert argobytes_clone.balance() == 0
    assert argobytes_trader.balance() == 0
    assert argobytes_actor.balance() == 0
    assert uniswap_v1_action.balance() == 0

    value = 1e18

    # send some ETH into the action to simulate arbitrage profits
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert accounts[0].balance() > value
    assert uniswap_v1_action.balance() == value
    assert argobytes_clone.balance() == 0

    usdc_exchange = uniswap_v1_factory.getExchange(usdc_erc20)
    dai_exchange = uniswap_v1_factory.getExchange(dai_erc20)

    # doesn't borrow anything because it trades ETH from the caller
    # TODO: do a test with weth9 and approvals instead
    borrows = []

    actions = [
        # trade ETH to USDC
        (
            uniswap_v1_action,
            1,
            # uniswap_v1_action.tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens)
            uniswap_v1_action.tradeEtherToToken.encode_input(uniswap_v1_action, usdc_exchange, usdc_erc20, 1),
        ),
        # trade USDC to DAI
        (
            uniswap_v1_action,
            0,
            # uniswap_v1_action.tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens)
            uniswap_v1_action.tradeTokenToToken.encode_input(
                uniswap_v1_action, usdc_exchange, usdc_erc20, dai_erc20, 1),
        ),
        # trade DAI to ETH
        (
            uniswap_v1_action,
            # uniswap_v1_action.tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens)
            uniswap_v1_action.tradeTokenToEther.encode_input(argobytes_clone, dai_exchange, dai_erc20, 1),
            False
        ),
    ]

    arbitrage_tx = argobytes_clone.execute(
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            address_zero,
            False,
            accounts[0],
            borrows,
            argobytes_actor,
            actions,
        ),
        {
            "value": value,
            "gasPrice": 0,
        }
    )

    # TODO: should we compare this to running with burning gas token?
    print("gas used: ", arbitrage_tx.gas_used)

    assert argobytes_clone.balance() > value

    # make sure the transaction succeeded
    assert arbitrage_tx.status == 1
    assert arbitrage_tx.return_value is not None

    # TODO: check event logs for profits
