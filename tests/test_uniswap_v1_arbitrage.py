import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
def test_uniswap_arbitrage(address_zero, argobytes_atomic_trade, dai_erc20, argobytes_owned_vault, example_action, chi, uniswap_v1_factory, uniswap_v1_action, usdc_erc20):
    assert argobytes_owned_vault.balance() == 0
    assert example_action.balance() == 0

    value = 1e18

    # send some ETH into the vault
    accounts[0].transfer(argobytes_owned_vault, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # mint some gas token
    # TODO: how much should we make?
    argobytes_owned_vault.mintGasToken(chi, 26, {"from": accounts[0]})

    # make sure balances match what we expect
    assert argobytes_owned_vault.balance() == value
    assert example_action.balance() == value

    usdc_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, usdc_erc20)
    dai_exchange = uniswap_v1_action.getExchange(uniswap_v1_factory, dai_erc20)

    # sweep a bunch of times to use up gas
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [
            example_action,
            uniswap_v1_action,
            uniswap_v1_action,
            uniswap_v1_action,
        ],
        [
            # add some faked profits
            example_action.sweep.encode_input(uniswap_v1_action, address_zero),

            # trade ETH to USDC
            # uniswap_v1_action.tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeEtherToToken.encode_input(uniswap_v1_action, usdc_exchange, usdc_erc20, 1, 0),

            # trade USDC to DAI
            # uniswap_v1_action.tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeTokenToToken.encode_input(
                uniswap_v1_action, usdc_exchange, usdc_erc20, dai_erc20, 1, 0),
            # trade DAI to ETH
            # uniswap_v1_action.tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens, uint trade_gas)
            uniswap_v1_action.tradeTokenToEther.encode_input(address_zero, dai_exchange, dai_erc20, 1, 0),
        ],
    )

    arbitrage_tx = argobytes_owned_vault.atomicArbitrage(
        chi, argobytes_atomic_trade, address_zero, [address_zero], value, encoded_actions, {'from': accounts[1]})

    assert argobytes_owned_vault.balance() > value

    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1
    assert arbitrage_tx.return_value is not None

    # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
    assert arbitrage_tx.return_value > 0

    # TODO: should we compare this to running without burning gas token?
    print("gas_used_with_gastoken: ", arbitrage_tx.gas_used)

    # TODO: make sure we didn't use all the gas token
