import click
import logging
import sys
import os
import contextlib
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from enum import IntFlag
from pprint import pprint
import multiprocessing
import os
import rlp
import tokenlists
from brownie import _cli, accounts, Contract, ETH_ADDRESS, project, ZERO_ADDRESS
from brownie.exceptions import VirtualMachineError
from brownie.network import web3
from eth_abi.packed import encode_abi_packed
from eth_utils import keccak, to_checksum_address, to_bytes, to_hex
from lazy_load import lazy
from argobytes.contracts import get_or_create, get_or_clone
from argobytes.tokens import print_token_balances
from brownie import accounts, project, network as brownie_network
from brownie._cli.console import Console
from brownie.network import gas_price
from brownie.network.gas.strategies import GasNowScalingStrategy
from pathlib import Path


logger = logging.getLogger("argobytes")


class BrownieAccount(click.ParamType):
    name = "brownie account"

    def convert(self, value, param, ctx):
        # TODO: if value.endswith(".json"): accounts.load(value)

        try:
            if value.endswith(".json"):
                return accounts.load(value)
            else:
                return accounts.at(value, force=True)
        except Exception as e:
            # TODO: what type of exception should we catch?
            self.fail(
                f"Brownie could not load named account {value!r}: {e}", param, ctx,
            )


BROWNIE_ACCOUNT = BrownieAccount()


def approve(account, balances, extra_balances, spender, amount=2 ** 256 - 1):
    """For every token that we have a balance of, Approve unlimited (or a specified amount) for the spender."""
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

            # approve_tx.info()

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

        # TODO: if debug, print this
        # approve_tx.info()


# TODO: this should be in brownie
def debug_shell(extra_locals, banner="Argobytes debug time.", exitmsg=""):
    """You probably want to use this with 'debug_shell(locals())'."""
    shell = _cli.console.Console(project.ArgobytesContractsProject, extra_locals)
    shell.interact(banner=banner, exitmsg=exitmsg)


def get_project_root() -> Path:
    """Root directory of the brownie project."""
    return Path(__file__).parent.parent


@contextlib.contextmanager
def print_start_and_end_balance(account):
    initial_gas = account.gas_used
    starting_balance = account.balance()

    print("\nbalance of", account, ":", starting_balance / 1e18)
    print()

    yield

    gas_used = account.gas_used - initial_gas
    ending_balance = account.balance()

    # TODO: print the number of transactions done?
    print(f"\n{account} used {gas_used} gas.")
    print(
        "\nspent balance of", account, ":", (starting_balance - ending_balance) / 1e18
    )
    print()


def prompt_loud_confirmation(account):
    print()
    print("*" * 80)

    if account is None:
        logger.warn(f"\nWARNING! Continuing past this will spend ETH!\n")
    else:
        logger.warn(f"\nWARNING! Continuing past this will spend ETH from {account}!\n")

    # TODO: print the active network/chain id
    click.confirm("\nDo you want to continue?\n", abort=True)


def with_dry_run(do_it, account):
    starting_balance = account.balance()

    """
    # TODO: fork should check if we are already connected to a forked network and just use snapshots
    with fork(unlock=str(account)) as fork_settings:
        with print_start_and_end_balance(account):
            do_it(account)

    prompt_for_confirmation(account)

    print("\nI hope it worked inside our test net, because we are doing it for real in 6 seconds... [Ctrl C] to cancel")
    time.sleep(6)
    """

    # TODO: also print start and end token balances
    with print_start_and_end_balance(account):
        do_it(account)

    print("transactions complete!")
