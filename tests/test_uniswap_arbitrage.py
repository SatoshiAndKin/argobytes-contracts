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
def test_uniswap_arbitrage(atomic_trade, owned_vault, example_action, uniswap_action, fn_isolation):
    value = 1e10

    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # make sure balances match what we expect
    assert owned_vault.balance() == value
    assert example_action.balance() == value

    dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

    # sweep a bunch of times to use up gas
    encoded_actions = atomic_trade.encodeActions(
        [
            uniswap_action,
            uniswap_action,
            uniswap_action,
            example_action,
        ],
        [
            # trade ETH to USDC
            # uniswap_action.tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
            uniswap_action.tradeEtherToToken.encode_input(
                uniswap_action, usdc, 1, 0, ""),
            # trade USDC to DAI
            # uniswap_action.tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
            uniswap_action.tradeTokenToToken.encode_input(
                uniswap_action, usdc, dai, 1, 0, ""),
            # trade DAI to ETH
            # uniswap_action.tradeTokenToEther(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
            uniswap_action.tradeTokenToEther.encode_input(
                example_action, zero_address, 1, 0, ""),
            # add some faked profits
            example_action.sweep.encode_input(zero_address),
        ],
    )

    arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    # make sure balances match what we expect
    assert arbitrage_tx.return_value == value
    assert owned_vault.balance() == 2 * value

    gas_used_without_gastoken = arbitrage_tx.gas_used

    print("gas_used_without_gastoken: ", gas_used_without_gastoken)

    # move the arb return back to the sweep contract
    owned_vault.withdrawTo(zero_address, example_action, value)

    # make sure balances match what we expect
    assert owned_vault.balance() == value
    assert example_action.balance() == value

    # mint some gas token
    # TODO: how much should we make?
    owned_vault.mintGasToken()
    owned_vault.mintGasToken()
    owned_vault.mintGasToken()

    # TODO: use gastoken interface to get the number of gas tokens available

    # do the faked arbitrage trade again (but this time with gas tokens)
    arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    gas_used_with_gastoken = arbitrage_tx.gas_used

    print("gas_used_with_gastoken: ", gas_used_with_gastoken)

    assert arbitrage_tx.return_value == value
    assert owned_vault.balance() == 2 * value
    assert gas_used_with_gastoken < gas_used_without_gastoken
    # TODO: assert something about the number of freed gas tokens
