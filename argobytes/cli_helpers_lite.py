"""CLI Helpers that you can bring in it import time."""
import logging
import sys
import time
from enum import Enum

import click
from brownie import accounts, chain, network, rpc, web3
from brownie._config import CONFIG
from decorator import decorator
from eth_utils.address import to_checksum_address

logger = logging.getLogger("argobytes")


class ReadOnlyAccount(click.ParamType):
    name = "account"

    def convert(self, value, param, ctx):
        # brownie needs an active network to setup the account
        # TODO: should this be on the --network flag? i think that would work well
        # TODO: is there some way to make sure --network is parsed first?
        ctx.obj["brownie_connect_fn"]()

        if is_forked_network():
            try:
                return accounts.at(value, force=True)
            except Exception as e:
                # TODO: catch a specific exception type
                self.fail(
                    f"Brownie could not get account {value!r}: {e}",
                    param,
                    ctx,
                )

        # TODO: resolve ENS
        if "." in value:
            return web3.ens.resolve(value)
        else:
            return to_checksum_address(value)


READ_ONLY_ACCOUNT = ReadOnlyAccount()


class BrownieAccount(click.ParamType):
    name = "account"

    def convert(self, value, param, ctx):
        from pathlib import Path

        from brownie import accounts

        # brownie needs an active network to setup the account
        ctx.obj["brownie_connect_fn"]()

        if value.endswith(".json"):
            print(f"Loading account @ {value}...")

            name, _ = value.rsplit(".")

            # TODO: read an environment var to allow customizing this?
            pass_dir = Path.home().joinpath(".argobytes/passwords")
            account_pass = None
            if pass_dir.exists():
                # TODO: is this the mode that we want?
                assert (
                    pass_dir.stat().st_mode == 0o40700
                ), "password dir must be mode 0700"

                possible_pass = pass_dir / f"{name}.pass"

                if possible_pass.exists():
                    with possible_pass.open("r") as f:
                        account_pass = f.read.strip()

            try:
                account = accounts.load(value, password=account_pass)
            except Exception as e:
                # TODO: catch a specific exception type
                self.fail(
                    f"Brownie could not load named account {value!r}: {e}",
                    param,
                    ctx,
                )
        else:
            # we just have an address. this is helpful in forked mode
            # TODO: don't alway force?
            # TODO: if brownie is not connected, exit with an error?
            try:
                account = accounts.at(value, force=True)
            except Exception as e:
                # TODO: catch a specific exception type
                self.fail(
                    f"Brownie could not get account {value!r}: {e}",
                    param,
                    ctx,
                )

        if isinstance(ctx.obj, dict):
            ctx.obj["lazy_contract_default_account"] = account
        else:
            ctx.obj = {"lazy_contract_default_account": account}
        # TODO: i just found this. do we need lazy_contract_default_account?
        CONFIG.active_network["settings"]["default_contract_owner"] = account

        return account


BROWNIE_ACCOUNT = BrownieAccount()


# TODO: refactor this for EIP-1559
gas_choices = click.Choice(["slow", "standard", "fast", "rapid"])


class Salt(click.ParamType):
    name = "salt"

    def convert(self, value, param, ctx):
        try:
            # TODO: what should we do with this value? we need to make sure its a bytes32
            return value
        except Exception as e:
            # TODO: what type of exception should we catch?
            self.fail(
                f"Could not parse '{value!r}' as a salt: {e}",
                param,
                ctx,
            )


SALT = Salt()

# TODO: is this the best way to have a common options? sometimes we want this as an argument and not an option
class CommandWithAccount(click.Command):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.params.append(
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
                help="ArgobytesFactory19 deploy salt",
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
def brownie_connect(func, *args, default_network=None, **kwargs):
    ctx = click.get_current_context()

    if default_network:
        ctx.obj["default_brownie_network"] = default_network

    connect_fn = ctx.obj["brownie_connect_fn"]
    connect_fn()

    return func(*args, **kwargs)


def prompt_loud_confirmation(account, confirm_delay_secs=6):
    """Wait for the user to press [enter] or abort."""
    print()
    print("*" * 80)

    # TODO: print the active network/chain id
    # TODO: print expected gas costs
    # TODO: safety check on gas costs
    # TODO: different chains have different token names.
    if account is None:
        logger.warning("Continuing past this will spend ETH!")
    else:
        # TODO: we might actually send from multiple accounts
        logger.warning("Continuing past this will spend ETH from %s!", account)

    click.secho(
        f"\nTransactions will run against the network at {web3.provider.endpoint_uri}!",
        fg="yellow",
    )

    click.confirm("\nDo you want to continue?", abort=True)

    # safety delay
    if confirm_delay_secs:
        click.secho(
            f"\nWe are doing it for real in {confirm_delay_secs} seconds!\n",
            fg="red",
            bold=True,
        )
        click.secho("[Ctrl C] to cancel\n", blink=True, bold=True, fg="red")

        time.sleep(confirm_delay_secs)


def with_dry_run(
    func,
    account,
    *args,
    tokens=None,
    confirm_delay_secs=6,
    replay_rpc=None,
    with_mainnet_run=False,
    prompt_mainnet_run=True,
    **kwargs,
):
    """Run a function against a fork network and then confirm before doing it for real.
    since we have an account, the @brownie_connect() decorator isn't needed
    """
    from argobytes.tokens import print_start_and_end_balance

    assert account, "no account!"
    assert network.show_active().endswith("-fork"), "must be on a forked network"

    def do_func():
        with print_start_and_end_balance(account, tokens):
            func(account, *args, **kwargs)

    # run the function connected to the forked network
    click.secho("Running transactions against a forked network", fg="yellow")
    do_func()

    # TODO: optionally open a console here

    if not network.history:
        print("No transactions were sent in the dry run. Exiting now")
        return

    # TODO: if account is not a LocalAccount, exit here since we can't sign with it

    if not with_mainnet_run:
        print(
            "Dry run completed successfully! Add '--with-mainnet-run' to broadcast for real."
        )
        return

    # replay_rpc might be set to something like eden network
    if not replay_rpc:
        # switch to the network that we forked from
        replay_rpc = get_upstream_rpc()

    orig_rpc = web3.provider.endpoint_uri

    # TODO: move this to a helper function. too many things need to be called in the right order
    # TODO: should we just web3.disconnect instead?
    network.history.clear()
    chain._network_disconnected()
    web3.connect(replay_rpc)
    web3.reset_middlewares()
    # disable snapshotting
    old_snapshot = rpc.snapshot
    old_sleep = rpc.sleep
    rpc.snapshot = lambda: 0
    rpc.sleep = lambda _: 0

    # we got this far and it didn't revert. prompt to send it to mainnet
    if prompt_mainnet_run:
        prompt_loud_confirmation(account, confirm_delay_secs)

    # send the transactions to the public
    do_func()

    print("transactions complete!")

    # TODO: optionally open a console here

    # return to the original network
    # TODO: move this to a helper function. too many things need to be called in the right order
    network.history.clear()
    chain._network_disconnected()
    web3.connect(orig_rpc)
    web3.reset_middlewares()
    # restore snapshotting
    rpc.snapshot = old_snapshot
    rpc.sleep = old_sleep


# damn circular immports
from argobytes.replay import get_upstream_rpc, is_forked_network
