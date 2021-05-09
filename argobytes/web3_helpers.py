# import functools

from brownie import Contract
from brownie.network import web3
from eth_utils import to_hex


def find_block_at(search_timestamp, average_block_time=None):
    """
    Finds a block with a timestamp close to the `search_timestamp`.

    TODO: this isn't perfect, but it works well enough
    """
    if average_block_time is None:
        average_block_time = get_average_block_time()
    # print("Average block time:", average_block_time)

    latest_block = web3.eth.getBlock("latest")

    # TODO: if search_timestamp is ahead of latest block, warn by how much

    # TODO: how much of a buffer should we add?
    blocks_to_search = (latest_block.timestamp - search_timestamp) / average_block_time * 2

    # we don't want to go too far back in time. so lets make an educated guess at the the first block to bother checking
    first_block_num = max(latest_block.number - blocks_to_search, 0)

    last_block_num = latest_block.number

    num_queries = 0
    needle = None
    mid_block = None
    while (first_block_num <= last_block_num) and (needle is None):
        mid_block_num = int((first_block_num + last_block_num) / 2)

        # print("block query!", mid_block_num)
        num_queries += 1
        mid_block = web3.eth.getBlock(mid_block_num)

        if mid_block.timestamp == search_timestamp:
            needle = mid_block
        else:
            if search_timestamp < mid_block.timestamp:
                last_block_num = mid_block_num - 1
            else:
                first_block_num = mid_block_num + 1

    if needle is None:
        # return the closest block
        # print("hopefully this is close enough!")
        if mid_block is None:
            needle = latest_block
        else:
            needle = mid_block

    # print("goal timestamp:", search_timestamp)
    # print("needle timestamp:", needle.timestamp)
    # print("timestamp diff:", needle.timestamp - search_timestamp)
    # print("needle block num:", needle.number)
    # print("found after", num_queries, "queries")

    return needle


def get_average_block_time(span=1000):
    # get the latest block
    latest_block = web3.eth.getBlock("latest")

    # get the block gap blocks ago
    # TODO: what if latest_block.number < span?
    old_block = web3.eth.getBlock(latest_block.number - span)

    # average block time
    return (latest_block.timestamp - old_block.timestamp) / span


def reset_block_time():
    # synthetix_address_resolver = interface.IAddressResolver(SynthetixAddressResolver)

    # TODO: get this from the address resolver instead
    synthetix_exchange_rates = Contract("0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77")

    token_bytestr = to_hex32(text="ETH")

    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time: ", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    # TODO: instead of last update time, just go back in time 10 years. no need to query SNX
    web3.testing.mine(last_update_time)


def to_hex32(primitive=None, hexstr=None, text=None):
    # TODO: eth_abi.encode_single('bytes32', b'Synthetix')
    return to_hex(primitive, hexstr, text).ljust(66, "0")
