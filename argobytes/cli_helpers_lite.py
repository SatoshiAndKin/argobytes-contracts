"""CLI Helpers that you can bring in it import time."""

import logging

import click
from decorator import decorator

logger = logging.getLogger("argobytes")


class BrownieAccount(click.ParamType):
    name = "account"

    def convert(self, value, param, ctx):
        from pathlib import Path

        from brownie import accounts

        # brownie needs an active network to setup the account
        if ctx and ctx.obj:
            connect_fn = ctx.obj["brownie_connect_fn"]

            connect_fn()

            # make a noop connect function in case this gets called again for some reason
            ctx.obj["brownie_connect_fn"] = lambda: None

        if value.endswith(".json"):
            print(f"Loading account @ {value}...")

            name, _ = value.rsplit(".")

            # TODO: read an environment var to allow customizing this?
            pass_dir = Path.home().joinpath(".argobytes/passwords")

            # TODO: is this the mode that we want?
            assert pass_dir.stat().st_mode == 0o40700, "password dir must be mode 0700"

            possible_pass = pass_dir / f"{name}.pass"

            if possible_pass.exists():
                with possible_pass.open("r") as f:
                    account_pass = f.read.strip()
            else:
                account_pass = None

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

    connect_fn = ctx.obj["brownie_connect_fn"]

    if default_network:
        ctx.obj["default_brownie_network"] = default_network

    connect_fn()

    return func(*args, **kwargs)
