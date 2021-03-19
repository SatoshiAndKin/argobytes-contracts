"""
Python scripts to make working with Argobytes smart contracts easy.
"""
import contextlib
# import functools
import multiprocessing
import os
import rlp
import tokenlists
from brownie import _cli, accounts, Contract, ETH_ADDRESS, project, ZERO_ADDRESS
from brownie.exceptions import VirtualMachineError
from brownie.network import web3
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from enum import IntFlag
from eth_abi.packed import encode_abi_packed
from eth_utils import keccak, to_checksum_address, to_bytes, to_hex
from lazy_load import lazy
from pprint import pprint


# TODO: circular imports
# from .contracts import get_or_clone, get_or_create, load_contract
# from .tokens import transfer_token, token_decimals



ActionTuple = namedtuple("Action", ["target", "call_type", "forward_value", "data",])


class CallType(IntFlag):
    DELEGATE = 0
    CALL = 1
    ADMIN = 2


class Action:
    def __init__(
        self,
        contract,
        call_type: CallType,
        forward_value: bool,
        function_name: str,
        *function_args,
    ):
        data = getattr(contract, function_name).encode_input(*function_args)

        self.tuple = ActionTuple(contract.address, call_type, forward_value, data)


def approve(account, balances, extra_balances, spender, amount=2 ** 256 - 1):
    for token, balance in balances.items():
        if token.address in extra_balances:
            balance += extra_balances[token.address]

        if balance == 0:
            continue

        allowed = token.allowance(account, spender)

        if allowed >= amount:
            print(f"No approval needed for {token.address}")
            # TODO: claiming 3crv could increase our balance and mean that we actually do need an approval
            continue
        elif allowed == 0:
            pass
        else:
            # TODO: do any of our tokens actually need this stupid check?
            print(f"Clearing {token.address} approval...")
            approve_tx = token.approve(spender, 0, {"from": account})

            approve_tx.info()

        if amount is None:
            print(
                f"Approving {spender} for {balance} of {account}'s {token.address}..."
            )
            amount = balance
        else:
            print(
                f"Approving {spender} for unlimited of {account}'s {token.address}..."
            )

        approve_tx = token.approve(spender, amount, {"from": account})

        approve_tx.info()


# TODO: this should be in brownie
def debug_shell(extra_locals, banner="Argobytes debug time.", exitmsg=""):
    """You probably want to use this with 'debug_shell(locals())'."""
    shell = _cli.console.Console(project.ArgobytesContractsProject, extra_locals)
    shell.interact(banner=banner, exitmsg=exitmsg)


def get_average_block_time(span=1000):
    # get the latest block
    latest_block = web3.eth.getBlock("latest")

    # get the block gap blocks ago
    old_block = web3.eth.getBlock(latest_block.number - span)

    # average block time
    return (latest_block.timestamp - old_block.timestamp) / span


def get_balances(account, tokens):
    # TODO: multicall
    return {token: token.balanceOf(account) for token in tokens}


def get_claimable_3crv(account, fee_distribution, min_crv=50):
    claimable = fee_distribution.claim.call(account)

    if claimable < min_crv:
        return 0

    return claimable



def find_block_at(search_timestamp):
    """
    Finds a block with a timestamp close to the `search_timestamp`.

    TODO: this isn't perfect, but it works well enough
    """
    average_block_time = get_average_block_time()
    # print("Average block time:", average_block_time)

    latest_block = web3.eth.getBlock("latest")

    # TODO: how much of a buffer should we add?
    blocks_to_search = (
        (latest_block.timestamp - search_timestamp) / average_block_time * 2
    )

    # we don't want to go too far back in time. so lets make an educated guess at the the first block to bother checking
    first_block_num = latest_block.number - blocks_to_search

    last_block_num = latest_block.number

    num_queries = 0
    needle = None
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
        needle = mid_block

    # print("goal timestamp:", search_timestamp)
    # print("needle timestamp:", needle.timestamp)
    # print("timestamp diff:", needle.timestamp - search_timestamp)
    # print("needle block num:", needle.number)
    # print("found after", num_queries, "queries")

    return needle


@contextlib.contextmanager
def print_start_and_end_balance(account):
    starting_balance = account.balance()

    print("\nbalance of", account, ":", starting_balance / 1e18)
    print()

    yield

    ending_balance = account.balance()

    # TODO: print gas_used
    print("\nspent balance of", account, ":", (starting_balance - ending_balance) / 1e18)
    print()


def print_token_balances(balances, label=None):
    # TODO: symbol cache
    dict_for_printing = dict()

    for token, amount in balances.items():
        symbol = token.symbol()

        if symbol:
            dict_for_printing[symbol] = amount
        else:
            dict_for_printing[token.address] = amount

    if label:
        print(label)

    pprint(dict_for_printing)


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

    # TODO: unstead of last update time we just went back 10 years
    web3.testing.mine(last_update_time)


def to_hex32(primitive=None, hexstr=None, text=None):
    return to_hex(primitive, hexstr, text).ljust(66, "0")
