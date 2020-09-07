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

    # TODO: what should we assert

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


# the trace shows the revert on `require(_notEntered, "re-entered")`, but we aren't seeing that message here
# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/571 or similar")
def test_compound_underlying_action(curve_fi_action, curve_fi_compound, dai_erc20, onesplit_helper, usdc_erc20):
    # buy some DAI for the curve_fi_action
    dai_balance = onesplit_helper(1e18, dai_erc20, curve_fi_action)

    dai_to_usdc_amounts = curve_fi_action.getAmounts(dai_erc20, dai_balance, usdc_erc20, curve_fi_compound)

    dai_to_usdc_extra_data = dai_to_usdc_amounts[0][5]

    curve_fi_action.tradeUnderlying(curve_fi_action, dai_erc20, usdc_erc20, 1, dai_to_usdc_extra_data)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = dai_to_usdc_amounts[1][5]

    curve_fi_action.tradeUnderlying(curve_fi_action, usdc_erc20, dai_erc20, 1, usdc_to_dai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things


# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/571 or similar")
def test_compound_action(curve_fi_action, curve_fi_compound, cdai_erc20, cusdc_erc20, onesplit_helper):
    # buy some cDAI for the curve_fi_action
    cdai_balance = onesplit_helper(1e18, cdai_erc20, curve_fi_action)

    cdai_to_cusdc_amounts = curve_fi_action.getAmounts(cdai_erc20, cdai_balance, cusdc_erc20, curve_fi_compound)

    cdai_to_cusdc_extra_data = cdai_to_cusdc_amounts[0][5]

    # TODO: wth. why is this reverting on transferring the cUSDC at the end?
    curve_fi_action.trade(curve_fi_action, cdai_erc20, cusdc_erc20, 1, cdai_to_cusdc_extra_data)

    # TODO: check balance of usdc and dai

    cusdc_to_cdai_extra_data = cdai_to_cusdc_amounts[1][5]

    curve_fi_action.trade(curve_fi_action, cusdc_erc20, cdai_erc20, 1, cusdc_to_cdai_extra_data)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things

# TODO: test trading on the y pool
