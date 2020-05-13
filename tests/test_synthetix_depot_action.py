from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie

zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(no_call_coverage, synthetix_depot_action, susd_erc20, skip_coverage):
    eth_amount = 1e18

    zero_address = "0x0000000000000000000000000000000000000000"

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a bug in brownie decoding their return_value!
    tx = synthetix_depot_action.getAmounts.transact(zero_address, eth_amount, susd_erc20)

    print("tx gas", tx.gas_used)

    # TODO: what should we assert?


def test_action(synthetix_depot_action, uniswap_action, dai_erc20, usdc_erc20):
    assert False
