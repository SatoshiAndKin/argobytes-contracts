from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie

zero_address = "0x0000000000000000000000000000000000000000"


def test_get_amounts(synthetix_address_resolver, synthetix_depot_action, susd_erc20):
    eth_amount = 1e18

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a bug in brownie decoding their return_value!
    amounts = synthetix_depot_action.getAmounts(zero_address, eth_amount, susd_erc20, synthetix_address_resolver)

    print("amounts", amounts)

    # TODO: what should we assert?

    # TODO: use named keys. they aren't currently supported
    # check that the selector is set
    assert amounts[0][4] != "0x00000000"
    assert amounts[1][4] == "0x00000000"


def test_action(synthetix_address_resolver, synthetix_depot_action, susd_erc20):
    eth_amount = 1e18

    # send some ETH into the action
    accounts[0].transfer(synthetix_depot_action, eth_amount)

    # make the trade for ETH -> sUSD
    amounts = synthetix_depot_action.getAmounts(zero_address, eth_amount, susd_erc20, synthetix_address_resolver)

    synthetix_depot_action.tradeEtherToSynthUSD(zero_address, 1, amounts[0][5], {"from": accounts[0]})

    # check the balance
    assert(susd_erc20.balanceOf(accounts[0]) > 0)
