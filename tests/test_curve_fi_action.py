import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
# TODO: they use 0xEeE..., but our wrapper handles the conversion
zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(curve_fi_action, usdc_erc20, dai_erc20, skip_coverage):
    amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b)
    tx = curve_fi_action.getAmounts.transact(usdc_erc20, amount, dai_erc20)

    print("tx 1 gas", tx.gas_used)

    # TODO: use amounts from the previous call
    tx = curve_fi_action.getAmounts.transact(dai_erc20, amount, usdc_erc20)

    print("tx 2 gas", tx.gas_used)

    # TODO: what should we assert?


def test_action(curve_fi_action, dai_erc20, uniswap_action, usdc_erc20):
    # put some ETH into the uniswap action so we can buy some DAI
    accounts[0].transfer(uniswap_action, 1e18)
    uniswap_action.tradeEtherToToken(curve_fi_action, dai_erc20, 1, 0, "")

    # now we have DAI in the curve_fi_action

    # our rust code will get this from getAmounts
    dai_to_usdc_extra_data = curve_fi_action.encodeExtraData(0, 1)

    curve_fi_action.tradeUnderlying(curve_fi_action, dai_erc20, usdc_erc20, 1, 0, dai_to_usdc_extra_data)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = curve_fi_action.encodeExtraData(1, 0)

    curve_fi_action.tradeUnderlying(curve_fi_action, usdc_erc20, dai_erc20, 1, 0, usdc_to_dai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things
