import logging
import os
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
from lazy_load import lazy
from hexbytes import HexBytes

from argobytes.contracts import get_or_clone, get_or_create, load_contract
from argobytes.tokens import load_token, load_token_or_contract, print_token_balances
from argobytes.transactions import get_event_contract, get_transaction, sync_tx_cache

logger = logging.getLogger("argobytes")


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


class BrownieAccount(click.ParamType):
    name = "account"

    def convert(self, value, param, ctx):
        # brownie needs an active network to setup the account
        if ctx and ctx.obj:
            connect_fn = ctx.obj["brownie_connect_fn"]

            connect_fn()

            # make a noop connect function in case this gets called again for some reason
            ctx.obj["brownie_connect_fn"] = lambda: None

        # check for private key in a file
        if value.endswith(".key"):
            try:
                key_path = Path(value).resolve()

                # check for secure permisions
                assert key_path.stat() == 0o100400, "key files must be mode 400"

                return accounts.add(key_path.read_text())
            except Exception as e:
                self.fail(
                    f"Brownie could not load account from {value!r}: {e}", param, ctx,
                )

        if value.endswith(".json"):
            try:
                return accounts.load(value)
            except Exception as e:
                self.fail(
                    f"Brownie could not load named account {value!r}: {e}", param, ctx,
                )

        # we just have an address. this is helpful in forked mode
        try:
            return accounts.at(value, force=True)
        except Exception as e:
            self.fail(
                f"Brownie could not get account {value!r}: {e}", param, ctx,
            )


BROWNIE_ACCOUNT = BrownieAccount()


class Salt(click.ParamType):
    name = "salt"

    def convert(self, value, param, ctx):
        try:
            # TODO: what should we do with this value? we need to make sure its a bytes32
            return value
        except Exception as e:
            # TODO: what type of exception should we catch?
            self.fail(
                f"Could not parse '{value!r}' as a salt: {e}", param, ctx,
            )


SALT = Salt()

# TODO: is this the best way to have a common options? sometimes we want this as an argument and not an option
class CommandWithAccount(click.Command):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.params.insert(
            0,
            click.core.Option(
                ("--account",),
                type=BROWNIE_ACCOUNT,
                help="Ethereum account, ENS name, brownie account",
                default="argobytes.json",
                show_default=True,
            ),
        )


# TODO: is this the best way to have a common options?
class CommandWithProxySalts(CommandWithAccount):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # TODO: insert at position 0? does it matter?
        self.params.insert(
            0,
            click.core.Option(
                ("--borrower-salt",),
                type=SALT,
                help="ArgobytesFlashBorrower deploy salt",
                default="",
                show_default=True,
            ),
        )
        self.params.insert(
            0,
            click.core.Option(
                ("--factory-salt",),
                type=SALT,
                help="ArgobytesFactory deploy salt",
                default="",
                show_default=True,
            ),
        )
        self.params.insert(
            0,
            click.core.Option(
                ("--clone-salt",),
                type=SALT,
                help="Account's clone's deploy salt",
                default="",
                show_default=True,
            ),
        )


@decorator
def brownie_connect(func, *args, **kwargs):
    ctx = click.get_current_context()

    connect_fn = ctx.obj["brownie_connect_fn"]

    connect_fn()

    return func(*args, **kwargs)


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


@decorator
def with_dry_run(func, account, tokens=None, *args, confirm_delay=6, **kwargs):
    """Run a function against a fork network and then confirm before doing it for real.
    
    since we have an account, the @brownie_connect decorator isn't needed
    """

    def do_func():
        with print_start_and_end_balance(account, tokens):
            func(account, *args, **kwargs)

    """
    # TODO: fork should check if we are already connected to a forked network and just use snapshots
    with fork(unlock=str(account)):
        do_func()
    """

    prompt_for_confirmation(account)

    click.secho(
        f"\nI hope it did what you wanted on our forked net, because we are doing it for real in {confirm_delay} seconds.\n\n",
        fg=red,
    )
    click.secho("[Ctrl C] to cancel", blink=True, bold=True, fg=red)
    time.sleep(confirm_delay)

    do_func()

    print("transactions complete!")
