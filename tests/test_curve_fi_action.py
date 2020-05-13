import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
# TODO: they use 0xEeE..., but our wrapper handles the conversion
zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(no_call_coverage, curve_fi_action, usdc_erc20, dai_erc20, skip_coverage):
    amount = 1e20

    # getAmounts(address token_a, uint token_a_amount, address token_b)
    tx = curve_fi_action.getAmounts.transact(usdc_erc20, amount, dai_erc20)

    print("tx 1 gas", tx.gas_used)

    # TODO: use amounts from the previous call
    tx = curve_fi_action.getAmounts.transact(dai_erc20, amount, usdc_erc20)

    print("tx 2 gas", tx.gas_used)

    # TODO: what should we assert?


def test_action(curve_fi_action, dai_erc20, usdc_erc20):
    assert False
