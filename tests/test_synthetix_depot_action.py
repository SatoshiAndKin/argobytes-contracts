from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
from argobytes_util import *
import pytest
import brownie

address_zero = "0x0000000000000000000000000000000000000000"


def test_byte_strs(synthetix_depot_action, web3):
    eth_bytestr = to_bytes32(text="ETH")

    # From `npx bytes32 ETH`
    eth_bytestr_hardcoded = to_bytes(hexstr="0x4554480000000000000000000000000000000000000000000000000000000000")

    assert eth_bytestr == eth_bytestr_hardcoded


def reset_block_time(synthetix_exchange_rates, token_bytestr, web3):
    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time:", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    web3.testing.mine(last_update_time)


def test_action(no_call_coverage, skip_coverage, synthetix_address_resolver, synthetix_depot_action, synthetix_exchange_rates, susd_erc20, web3):
    eth_amount = 1e18

    # send some ETH into the action
    accounts[0].transfer(synthetix_depot_action, eth_amount)

    eth_bytestr = synthetix_depot_action.BYTESTR_ETH()

    reset_block_time(synthetix_exchange_rates, eth_bytestr, web3)

    # make the trade for ETH -> sUSD
    synthetix_depot_action.tradeEtherToSynthUSD(address_zero, 1, depot, sUSD, {"from": accounts[0]})

    # check the balance
    assert(susd_erc20.balanceOf(accounts[0]) > 0)
