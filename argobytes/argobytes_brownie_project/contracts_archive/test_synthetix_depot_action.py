import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

from argobytes.web3_helpers import to_hex32


def test_byte_strs(synthetix_depot_action, web3):
    eth_bytestr = to_hex32(text="ETH")

    # From `npx bytes32 ETH`
    eth_bytestr_hardcoded = to_hex(hexstr="0x4554480000000000000000000000000000000000000000000000000000000000")

    assert eth_bytestr == eth_bytestr_hardcoded


def reset_block_time(synthetix_exchange_rates, token_bytestr, web3):
    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time:", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    web3.testing.mine(last_update_time)


def test_action(
    no_call_coverage,
    susd_erc20,
    synthetix_address_resolver,
    synthetix_depot,
    synthetix_depot_action,
    synthetix_exchange_rates,
    web3,
):
    eth_amount = 2e17

    # TODO: add some sUSD to the depot if there isn't enough

    # send some ETH into the action
    accounts[0].transfer(synthetix_depot_action, eth_amount)

    eth_bytestr = to_hex32(text="ETH")

    reset_block_time(synthetix_exchange_rates, eth_bytestr, web3)

    # make the trade for ETH -> sUSD
    tx = synthetix_depot_action.tradeEtherToSynthUSD(accounts[0], 1, synthetix_depot, susd_erc20, {"from": accounts[0]})

    # check the balance
    assert susd_erc20.balanceOf(accounts[0]) > 0
