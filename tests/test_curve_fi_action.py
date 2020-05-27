import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
# TODO: they use 0xEeE..., but our wrapper handles the conversion
address_zero = "0x0000000000000000000000000000000000000000"


def test_compound_get_amounts(curve_fi_action, curve_fi_compound, usdc_erc20, dai_erc20):
    trade_amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b, address curve_fi_exchange)
    amounts = curve_fi_action.getAmounts(usdc_erc20, trade_amount, dai_erc20, curve_fi_compound)

    print("amount 1", amounts)

    # TODO: use maker_wei from the previous call. then these amounts should be the same, but just re-ordered
    amounts = curve_fi_action.getAmounts(dai_erc20, trade_amount, usdc_erc20, curve_fi_compound)

    print("amount 2", amounts)

    # TODO: what should we assert?


def test_compound_get_underlying_amounts(curve_fi_action, curve_fi_compound, cusdc_erc20, cdai_erc20):
    trade_amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b, address curve_fi_exchange)
    amounts = curve_fi_action.getAmounts(cusdc_erc20, trade_amount, cdai_erc20, curve_fi_compound)

    print("amount 1", amounts)

    # TODO: use amounts from the previous call
    amounts = curve_fi_action.getAmounts(cdai_erc20, trade_amount, cusdc_erc20, curve_fi_compound)

    print("amount 2", amounts)

    # TODO: what should we assert?


@pytest.mark.skip(reason="uniswap_helper is under construction")
def test_compound_action(curve_fi_action, curve_fi_compound, cdai_erc20, uniswap_helper, cusdc_erc20, dai_erc20, usdc_erc20):
    # buy some cDAI for the curve_fi_action
    _cdai_amount = uniswap_helper(1e18, cdai_erc20, curve_fi_action)

    # our rust code will get this from getAmounts
    # TODO: use getAmounts here
    dai_to_usdc_extra_data = curve_fi_action.encodeExtraData(curve_fi_compound, 0, 1)

    curve_fi_action.trade(curve_fi_action, cdai_erc20, cusdc_erc20, 1, dai_to_usdc_extra_data)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = curve_fi_action.encodeExtraData(curve_fi_compound, 1, 0)

    curve_fi_action.trade(curve_fi_action, cusdc_erc20, cdai_erc20, 1, usdc_to_dai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things

    # buy some DAI for the curve_fi_action
    _dai_amount = uniswap_helper(1e18, dai_erc20, curve_fi_action)

    # our rust code will get this from getAmounts
    dai_to_usdc_extra_data = curve_fi_action.encodeExtraData(curve_fi_compound, 0, 1)

    curve_fi_action.tradeUnderlying(curve_fi_action, dai_erc20, usdc_erc20, 1, dai_to_usdc_extra_data)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = curve_fi_action.encodeExtraData(curve_fi_compound, 1, 0)

    curve_fi_action.tradeUnderlying(curve_fi_action, usdc_erc20, dai_erc20, 1, usdc_to_dai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things
