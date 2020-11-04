import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

from argobytes_mainnet import CurveFiCompoundAddress


# TODO: parametrize this
@pytest.mark.xfail(reason="bug in ganache-cli? tradeUnderlying works, so this should, too")
def test_compound_action(curve_fi_action, curve_fi_compound, cdai_erc20, cusdc_erc20, onesplit_helper):
    # buy some cDAI for the curve_fi_action
    cdai_balance = onesplit_helper(1e18, cdai_erc20, curve_fi_action)

    # TODO: get i/j from the token addresses

    curve_fi_action.trade(CurveFiCompoundAddress, 0, 1, curve_fi_action, cdai_erc20, cusdc_erc20, 1)

    # TODO: check balance of cusdc and cdai

    curve_fi_action.trade(CurveFiCompoundAddress, 1, 0, curve_fi_action, cusdc_erc20, cdai_erc20, 1)
    # TODO: check balance of cusdc and cdai
    # TODO: actually assert things


# TODO: parametrize this
def test_compound_underlying_action(curve_fi_action, curve_fi_compound, dai_erc20, onesplit_helper, usdc_erc20):
    # buy some DAI for the curve_fi_action
    dai_balance = onesplit_helper(1e18, dai_erc20, curve_fi_action)

    # TODO: get i/j from the token addresses

    curve_fi_action.tradeUnderlying(CurveFiCompoundAddress, 0, 1, curve_fi_action, dai_erc20, usdc_erc20, 1)

    # TODO: check balance of usdc and dai

    curve_fi_action.tradeUnderlying(CurveFiCompoundAddress, 1, 0, curve_fi_action, usdc_erc20, dai_erc20, 1)

    # TODO: check balance of usdc and dai
    # TODO: actually assert things


# TODO: test trading on other pools
