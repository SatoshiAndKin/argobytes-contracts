from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie

address_zero = "0x0000000000000000000000000000000000000000"


def test_byte_strs(synthetix_depot_action, web3):
    # This needs to match `npx bytes32 ETH`
    eth_bytestr = web3.toHex(text="ETH").ljust(2+(32)*2, '0')

    eth_bytestr_hardcoded = "0x4554480000000000000000000000000000000000000000000000000000000000"

    assert eth_bytestr == eth_bytestr_hardcoded

    eth_bytestr_contract = synthetix_depot_action.BYTESTR_ETH()

    assert eth_bytestr == eth_bytestr_contract


def reset_block_time(synthetix_exchange_rates, token_bytestr, web3):
    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time:", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    web3.testing.mine(last_update_time)


def test_invalid_get_amounts(synthetix_address_resolver, synthetix_depot_action, synthetix_exchange_rates, usdc_erc20, web3):
    # try getting amounts for usdc (but depot only supports ETH -> sUSD)

    eth_amount = 1e18

    eth_bytestr = synthetix_depot_action.BYTESTR_ETH()

    # synthetix rates are only valid for 3 hours. ganache-cli times sometimes end up incremented by over 4 hours
    reset_block_time(synthetix_exchange_rates, eth_bytestr, web3)

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a bug in brownie decoding their return_value!
    amounts = synthetix_depot_action.getAmounts(address_zero, eth_amount, usdc_erc20, synthetix_address_resolver)

    print("amounts", amounts)

    # TODO: what should we assert?

    # check that we have the expected error
    assert amounts[0][7] != ""
    # this won't have an error in it, but it might in the future. we don't really care
    # assert amounts[1][7] != ""

    # TODO: use named keys. they aren't currently supported
    # check that the selector is set
    assert amounts[0][4] == "0x00000000"
    assert amounts[1][4] == "0x00000000"


def test_get_amounts(synthetix_address_resolver, synthetix_depot_action, synthetix_exchange_rates, susd_erc20, web3):
    eth_amount = 1e18

    eth_bytestr = synthetix_depot_action.BYTESTR_ETH()

    # synthetix rates are only valid for 3 hours. ganache-cli times sometimes end up incremented by over 4 hours
    reset_block_time(synthetix_exchange_rates, eth_bytestr, web3)

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    # TODO: we could call these, but there is a bug in brownie decoding their return_value!
    amounts = synthetix_depot_action.getAmounts(address_zero, eth_amount, susd_erc20, synthetix_address_resolver)

    print("amounts", amounts)

    # TODO: what should we assert?

    # check that we have the expected (lack of) errors
    assert amounts[0][7] == ""
    # this used to be an error, but now it isn't
    assert amounts[1][7] == ""

    # TODO: use named keys. they aren't currently supported
    # check that the selector is set
    assert amounts[0][4] != "0x00000000"
    assert amounts[1][4] == "0x00000000"


def test_action(no_call_coverage, skip_coverage, synthetix_address_resolver, synthetix_depot_action, synthetix_exchange_rates, susd_erc20, web3):
    eth_amount = 1e18

    # send some ETH into the action
    accounts[0].transfer(synthetix_depot_action, eth_amount)

    eth_bytestr = synthetix_depot_action.BYTESTR_ETH()

    reset_block_time(synthetix_exchange_rates, eth_bytestr, web3)

    # make the trade for ETH -> sUSD
    amounts = synthetix_depot_action.getAmounts(address_zero, eth_amount, susd_erc20, synthetix_address_resolver)

    synthetix_depot_action.tradeEtherToSynthUSD(address_zero, 1, amounts[0][5], {"from": accounts[0]})

    # check the balance
    assert(susd_erc20.balanceOf(accounts[0]) > 0)
