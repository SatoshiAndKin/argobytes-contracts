# TODO: create a arbitrage opportunity on the staging node
from brownie import *


def reset_block_time(synthetix_depot_action):
    # synthetix_address_resolver = interface.IAddressResolver(SynthetixAddressResolver)

    # TODO: get this from the address resolver instead
    synthetix_exchange_rates = Contract("0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77")

    token_bytestr = synthetix_depot_action.BYTESTR_ETH()

    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time: ", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    web3.testing.mine(last_update_time)


def main():
    synthetix_depot_action = None  # TODO: how should we get this?
    argobytes_multicall = None

    reset_block_time(synthetix_depot_action)

    # put some ETH on the atomic trade wrapper to fake an arbitrage opportunity
    # TODO: make a script to help with this
    accounts[1].transfer(argobytes_multicall, 1e18)
