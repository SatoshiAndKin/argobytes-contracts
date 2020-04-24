import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
# TODO: coverage seems to crash this test because it takes so much gas. use `no_call_coverage` or `skip_coverage` fixture
def test_action(onesplit, onesplit_onchain_action, dai_erc20, usdc_erc20):
    value = 1e17

    # make sure balances match what we expect
    assert onesplit_onchain_action.balance() == 0

    # send some ETH into the action
    accounts[0].transfer(onesplit_onchain_action, value)

    # make sure balances match what we expect
    assert onesplit_onchain_action.balance() == value

    parts = 1
    # TODO: if disable_flags is 0, it takes a TON of gas. instead we only enable the top 3 exchanges
    disable_flags = 0

    # disable_flags |= onesplit.FLAG_DISABLE_UNISWAP()
    # disable_flags |= onesplit.FLAG_DISABLE_KYBER()
    disable_flags |= onesplit.FLAG_DISABLE_BANCOR.call()
    disable_flags |= onesplit.FLAG_DISABLE_OASIS.call()
    disable_flags |= onesplit.FLAG_DISABLE_COMPOUND.call()
    disable_flags |= onesplit.FLAG_DISABLE_FULCRUM.call()
    disable_flags |= onesplit.FLAG_DISABLE_CHAI.call()
    disable_flags |= onesplit.FLAG_DISABLE_AAVE.call()
    disable_flags |= onesplit.FLAG_DISABLE_SMART_TOKEN.call()
    disable_flags |= onesplit.FLAG_DISABLE_BDAI.call()
    disable_flags |= onesplit.FLAG_DISABLE_IEARN.call()
    disable_flags |= onesplit.FLAG_DISABLE_CURVE_COMPOUND.call()
    disable_flags |= onesplit.FLAG_DISABLE_CURVE_USDT.call()
    disable_flags |= onesplit.FLAG_DISABLE_CURVE_Y.call()
    disable_flags |= onesplit.FLAG_DISABLE_CURVE_BINANCE.call()
    disable_flags |= onesplit.FLAG_DISABLE_SMART_TOKEN.call()
    disable_flags |= onesplit.FLAG_DISABLE_WETH.call()
    # TODO: this isn't on mainnet yet
    # disable_flags |= onesplit.FLAG_DISABLE_IDLE.call()

    disable_flags |= onesplit.FLAG_ENABLE_MULTI_PATH_DAI.call()
    disable_flags |= onesplit.FLAG_ENABLE_MULTI_PATH_USDC.call()

    extra_data = onesplit_onchain_action.encodeExtraData(parts, disable_flags)

    print("extra_data: ", extra_data)

    # trade ETH to USDC
    # tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    # TODO: this is taking WAY WAY WAY too much gas. we should
    onesplit_onchain_action.tradeEtherToToken(onesplit_onchain_action, usdc_erc20, 1, 0, extra_data)

    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # trade USDC to DAI
    # tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    # tracing this transaction is crashing the RPC
    onesplit_onchain_action.tradeTokenToToken(
        onesplit_onchain_action, usdc_erc20, dai_erc20, 1, 0, extra_data)

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    onesplit_onchain_action.tradeTokenToEther(accounts[0], dai_erc20, 1, 0, extra_data)

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero
