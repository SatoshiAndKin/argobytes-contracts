"""CLI helpers that you should import inside the logic parts (outside of where click decorators are)."""
from decimal import Decimal
from pathlib import Path

import brownie
import click
import eth_abi
import eth_utils
import rlp
import tokenlists
from ape_safe import ApeSafe
from brownie import ETH_ADDRESS, ZERO_ADDRESS, Contract, _cli, accounts
from brownie import network as brownie_network
from brownie import project
from brownie._cli.console import Console
from brownie.exceptions import VirtualMachineError
from brownie.network import gas_price, web3
from brownie.network.gas.strategies import GasNowScalingStrategy
from decorator import decorator
from eth_abi.packed import encode_abi_packed
from eth_utils import keccak, to_bytes, to_checksum_address, to_hex
from hexbytes import HexBytes
from lazy_load import lazy

from argobytes.contracts import get_or_clone, get_or_create, lazy_contract, load_contract
from argobytes.tokens import load_token, load_token_or_contract, print_token_balances
from argobytes.transactions import get_event_contract, get_transaction, sync_tx_cache


COMMON_HELPERS = {
    "brownie": brownie,
    "ApeSafe": ApeSafe,
    "Decimal": Decimal,
    "HexBytes": HexBytes,
    "eth_abi": eth_abi,
    "eth_utils": eth_utils,
    "get_event_contract": get_event_contract,
    "get_transaction": get_transaction,
    "history": brownie_network.history,
    "load_contract": load_contract,
    "load_token": load_token,
    "load_token_or_contract": load_token_or_contract,
    "sync_tx_cache": sync_tx_cache,
}


def debug_shell(extra_locals, banner="Argobytes debug time.", exitmsg=""):
    """You probably want to use this with 'debug_shell(locals())'."""
    extra_locals.update(COMMON_HELPERS)

    shell = _cli.console.Console(project.ArgobytesContractsProject, extra_locals)
    shell.interact(banner=banner, exitmsg=exitmsg)


def get_project_root() -> Path:
    """Root directory of the brownie project."""
    return Path(__file__).parent.parent


def prompt_loud_confirmation(account):
    print()
    print("*" * 80)

    if account is None:
        logger.warn(f"\nWARNING! Continuing past this will spend ETH!\n")
    else:
        logger.warn(f"\nWARNING! Continuing past this will spend ETH from {account}!\n")

    # TODO: print the active network/chain id
    click.confirm("\nDo you want to continue?\n", abort=True)
