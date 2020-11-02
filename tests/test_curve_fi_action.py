import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
# TODO: they use 0xEeE..., but our wrapper handles the conversion
address_zero = "0x0000000000000000000000000000000000000000"


# the trace shows the revert on `require(_notEntered, "re-entered")`, but we aren't seeing that message here
# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/571 or similar")
def test_compound_underlying_action(curve_fi_action, curve_fi_compound, dai_erc20, onesplit_helper, usdc_erc20):
    # buy some DAI for the curve_fi_action
    dai_balance = onesplit_helper(1e18, dai_erc20, curve_fi_action)

    # TODO: update
    curve_fi_action.tradeUnderlying(curve_fi_action, dai_erc20, usdc_erc20, 1)

    # TODO: check balance of usdc and dai

    usdc_to_dai_extra_data = dai_to_usdc_amounts[1][5]

    curve_fi_action.tradeUnderlying(curve_fi_action, usdc_erc20, dai_erc20, 1)

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
