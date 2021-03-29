import click
import logging
import sys
import os

from argobytes import print_start_and_end_balance, print_token_balances
from argobytes.contracts import get_or_create, get_or_clone
from brownie import accounts, project, network as brownie_network
from brownie._cli.console import Console
from brownie.network import gas_price
from brownie.network.gas.strategies import GasNowScalingStrategy

# from brownie.utils import fork
from pathlib import Path


logger = logging.getLogger("argobytes")


# TODO: refactor this to use click helpers
def prompt_for_confirmation(account):
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


def get_project_root() -> Path:
    return Path(__file__).parent.parent
