import brownie
import pytest
import warnings
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @pytest.mark.xfail(reason="test passes when its run by itself, but it fails when everything is run together. started working with the fix-fork branch ganache-cli?")
def test_uniswap_arbitrage(address_zero, argobytes_atomic_trade, argobytes_owned_vault, uniswap_v1_factory, uniswap_v1_action, usdc_erc20, weth9_erc20):
    assert argobytes_owned_vault.balance() == 0
    assert uniswap_v1_action.balance() == 0

    value = 1e18

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)
    # send some ETH into the action to simulate arbitrage profits
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert argobytes_owned_vault.balance() == value
    assert uniswap_v1_action.balance() == value

    usdc_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, usdc_erc20)
    weth9_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, weth9_erc20)

    encoded_actions = argobytes_atomic_trade.encodeActions(
        [
            uniswap_v1_action,
            uniswap_v1_action,
            uniswap_v1_action,
        ],
        [
            # trade ETH to USDC
            # uniswap_v1_action.tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeEtherToToken.encode_input(uniswap_v1_action, usdc_exchange, usdc_erc20, 1, 0),

            # trade USDC to WETH9
            # uniswap_v1_action.tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeTokenToToken.encode_input(
                uniswap_v1_action, usdc_exchange, usdc_erc20, weth9_erc20, 1, 0),

            # trade WETH9 to ETH
            # uniswap_v1_action.tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeTokenToEther.encode_input(address_zero, weth9_exchange, weth9_erc20, 1, 0),
        ],
        [True, False, False],
    )

    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        address_zero, argobytes_atomic_trade, address_zero, [address_zero], value, encoded_actions, {'from': accounts[1]})

    assert argobytes_owned_vault.balance() > value

    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1

    if arbitrage_tx.return_value is None:
        warnings.warn("return value is None when it should not be! https://github.com/trufflesuite/ganache-cli/issues/758")
    else:
        # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
        assert arbitrage_tx.return_value > 0

    # TODO: should we compare this to running with burning gas token?
    print("gas used: ", arbitrage_tx.gas_used)
