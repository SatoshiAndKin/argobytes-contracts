"""CLI helpers that you should import inside the logic parts (outside of where click decorators are)."""
from decimal import Decimal
from pathlib import Path

import brownie
import click
import eth_abi
import eth_utils
import IPython

# from ape_safe import ApeSafe
from brownie import network as brownie_network
from hexbytes import HexBytes

from argobytes.cli_helpers_lite import logger
from argobytes.contracts import ArgobytesBrownieProject, ArgobytesInterfaces, load_contract
from argobytes.tokens import load_token, load_token_or_contract
from argobytes.transactions import get_event_address, get_event_contract, get_transaction, sync_tx_cache

COMMON_HELPERS = {
    "ArgobytesBrownieProject": ArgobytesBrownieProject,
    "ArgobytesInterfaces": ArgobytesInterfaces,
    # "ApeSafe": ApeSafe,
    "brownie": brownie,
    "brownie_history": brownie_network.history,
    "Decimal": Decimal,
    "HexBytes": HexBytes,
    "eth_abi": eth_abi,
    "eth_utils": eth_utils,
    "get_event_address": get_event_address,
    "get_event_contract": get_event_contract,
    "get_transaction": get_transaction,
    "load_contract": load_contract,
    "load_token": load_token,
    "load_token_or_contract": load_token_or_contract,
    "sync_tx_cache": sync_tx_cache,
    "web3": brownie.web3,
}


def debug_shell(extra_locals, banner="Argobytes debug time.", exitmsg=""):
    """You probably want to use this with 'debug_shell(locals())'.

    TODO: use ipython
    """
    if banner:
        print(banner)

    extra_locals.update(COMMON_HELPERS)

    IPython.start_ipython(argv=[], user_ns=extra_locals)

    if exitmsg:
        print(exitmsg)


def get_project_root() -> Path:
    """Root directory of the brownie project."""
    return Path(__file__).parent.joinpath("argobytes_brownie_project")


def prompt_loud_confirmation(account):
    """Wait for the user to press [enter] or abort."""
    print()
    print("*" * 80)

    if account is None:
        logger.warning("\nWARNING! Continuing past this will spend ETH!\n")
    else:
        logger.warning("\nWARNING! Continuing past this will spend ETH from %s!\n", account)

    # TODO: print the active network/chain id
    click.confirm("\nDo you want to continue?\n", abort=True)
