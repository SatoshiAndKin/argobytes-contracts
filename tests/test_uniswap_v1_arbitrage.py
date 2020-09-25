import brownie
import pytest
import warnings
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/611")
def test_uniswap_arbitrage(address_zero, argobytes_actor, argobytes_trader, argobytes_proxy, uniswap_v1_factory, uniswap_v1_action, usdc_erc20, weth9_erc20):
    assert argobytes_proxy.balance() == 0
    assert uniswap_v1_action.balance() == 0

    value = 1e18

    # send some ETH into the action to simulate arbitrage profits
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert accounts[0].balance() > value
    assert uniswap_v1_action.balance() == value

    usdc_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, usdc_erc20)
    weth9_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, weth9_erc20)

    # doesn't borrow anything because it trades ETH from the caller
    borrows = []

    actions = [
        # trade ETH to USDC
        (
            uniswap_v1_action,
            # uniswap_v1_action.tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeEtherToToken.encode_input(uniswap_v1_action, usdc_exchange, usdc_erc20, 1, 0),
            True,
        ),
        # trade USDC to WETH9
        (
            uniswap_v1_action,
            # uniswap_v1_action.tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeTokenToToken.encode_input(
                uniswap_v1_action, usdc_exchange, usdc_erc20, weth9_erc20, 1, 0),
            False,
        ),
        # trade WETH9 to ETH
        (
            uniswap_v1_action,
            # uniswap_v1_action.tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeTokenToEther.encode_input(address_zero, weth9_exchange, weth9_erc20, 1, 0),
            False
        ),
    ]

    arbitrage_tx = argobytes_proxy.execute(
        False,
        False,
        argobytes_trader.address,
        argobytes_trader.atomicArbitrage.encode_input(
            borrows, argobytes_actor, actions
        ),
        {
            "value": value,
        }
    )

    assert argobytes_proxy.balance() > value

    # TODO: https://github.com/trufflesuite/ganache-core/issues/611
    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1
    assert arbitrage_tx.return_value is not None

    # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
    assert arbitrage_tx.return_value > 0

    # TODO: should we compare this to running with burning gas token?
    print("gas used: ", arbitrage_tx.gas_used)
