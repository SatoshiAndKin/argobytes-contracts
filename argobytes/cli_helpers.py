import click
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


# TODO: refactor this to use click helpers
def prompt_for_account(default="satoshiandkin.eth"):
    """Prompt the user for an eth account."""
    # TODO: use click helper for this?
    # TODO: create it if it doesn't exist?
    # account = accounts.load('argobytes-extra')

    # TODO: just hard code to my hardware wallet for now
    account = accounts.at(default, force=True)

    print("hello,", account)

    return account


# TODO: refactor this to use click helpers
def prompt_for_confirmation(account):
    print()
    print("*" * 80)

    if account is None:
        print(f"\nWARNING! Continuing past this will spend ETH!\n")
    else:
        print(f"\nWARNING! Continuing past this will spend ETH from {account}!\n")

    # TODO: print the active network/chain id
    input("\nPress [Enter] to continue.\n")


# TODO: name this better
def with_dry_run(do_it):
    account = prompt_for_account()

    starting_balance = account.balance()

    # TODO: write my own strategy based on GethMempoolStrategy
    # TODO: have rapid and fast? some scripts might even want slow
    # https://eth-brownie.readthedocs.io/en/stable/core-gas.html#building-your-own-gas-strategy
    gas_strategy = GasNowScalingStrategy("fast", increment=1.2)

    print("Using 0 gwei gas price in dev!")
    gas_strategy = 0

    """
    # TODO: fork should check if we are already connected to a forked network and just use snapshots
    with fork(unlock=str(account)) as fork_settings:
        gas_price(gas_strategy)

        with print_start_and_end_balance(account):
            do_it(account)

    prompt_for_confirmation(account)

    print("\nI hope it worked inside our test net, because we are doing it for real in 6 seconds... [Ctrl C] to cancel")
    time.sleep(6)
    """

    """
    for some scripts, it will be fine to replay exactly the same txs with something like this:

        # for tx in checked_transactions:
        #     debug_shell(locals())

    for other scripts, i can see wanting to run `do_it` again. running do_it seems the safest since state changes fast
    i also don't have complete faith in our forked testnet being 100% accurate
    """
    with print_start_and_end_balance(account):
        gas_price(gas_strategy)

        do_it(account)

    print("transactions complete!")


def get_project_root() -> Path:
    return Path(__file__).parent.parent
