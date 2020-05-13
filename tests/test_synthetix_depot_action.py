from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie

zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(synthetix_depot_action, susd_erc20, skip_coverage):
    eth_amount = 1e18

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a bug in brownie decoding their return_value!
    tx = synthetix_depot_action.getAmounts.transact(zero_address, eth_amount, susd_erc20)

    print("tx gas", tx.gas_used)

    # TODO: what should we assert?


def test_action(synthetix_depot_action, susd_erc20):
    eth_value = 1e18

    # send some ETH into the action
    accounts[0].transfer(synthetix_depot_action, eth_value)

    # make the trade for ETH -> sUSD
    synthetix_depot_action.tradeEtherToSynthUSD(zero_address, 1, {"from": accounts[0]})

    # check the balance
    assert(susd_erc20.balanceOf(accounts[0]) > 0)
