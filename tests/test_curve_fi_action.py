import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
# TODO: they use 0xEeE..., but our wrapper handles the conversion
zero_address = "0x0000000000000000000000000000000000000000"


def test_compound_get_amounts(curve_fi_compound_action, usdc_erc20, dai_erc20):
    trade_amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b)
    amounts = curve_fi_compound_action.getAmounts(usdc_erc20, trade_amount, dai_erc20)

    print("amount 1", amounts)

    # TODO: use maker_wei from the previous call. then these amounts should be the same, but just re-ordered
    amounts = curve_fi_compound_action.getAmounts(dai_erc20, trade_amount, usdc_erc20)

    print("amount 2", amounts)

    # TODO: what should we assert?


def test_compound_get_underlying_amounts(curve_fi_compound_action, cusdc_erc20, cdai_erc20):
    trade_amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b)
    amounts = curve_fi_compound_action.getAmounts(cusdc_erc20, trade_amount, cdai_erc20)

    print("amount 1", amounts)

    # TODO: use amounts from the previous call
    amounts = curve_fi_compound_action.getAmounts(cdai_erc20, trade_amount, cusdc_erc20)

    print("amount 2", amounts)

    # TODO: what should we assert?


def test_compound_action(curve_fi_compound_action, cdai_erc20, uniswap_action, cusdc_erc20, dai_erc20, usdc_erc20):
    # put some ETH into the uniswap action so we can buy some DAI
    accounts[0].transfer(uniswap_action, 1e18)
    uniswap_action.tradeEtherToToken(curve_fi_compound_action, cdai_erc20, 1, 0, "")

    # now we have cDAI in the curve_fi_compound_action

    # our rust code will get this from getAmounts
    dai_to_usdc_extra_data = curve_fi_compound_action.encodeExtraData(0, 1)

    curve_fi_compound_action.trade(curve_fi_compound_action, cdai_erc20, cusdc_erc20, 1, dai_to_usdc_extra_data)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = curve_fi_compound_action.encodeExtraData(1, 0)

    curve_fi_compound_action.trade(curve_fi_compound_action, cusdc_erc20, cdai_erc20, 1, usdc_to_dai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things

    # TODO: the below should be in a seperate test. but for some reason we get a revert from compound about re-entrancy
    # put some ETH into the uniswap action so we can buy some DAI
    accounts[0].transfer(uniswap_action, 1e18)
    uniswap_action.tradeEtherToToken(curve_fi_compound_action, dai_erc20, 1, 0, "")

    # now we have DAI in the curve_fi_compound_action

    # our rust code will get this from getAmounts
    dai_to_usdc_extra_data = curve_fi_compound_action.encodeExtraData(0, 1)

    curve_fi_compound_action.tradeUnderlying(curve_fi_compound_action, dai_erc20, usdc_erc20, 1, dai_to_usdc_extra_data)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = curve_fi_compound_action.encodeExtraData(1, 0)

    curve_fi_compound_action.tradeUnderlying(curve_fi_compound_action, usdc_erc20, dai_erc20, 1, usdc_to_dai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things
