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
        # TODO: i'd like to be able to set the default network smarter
        if ctx and ctx.obj:
            connect_fn = ctx.obj["brownie_connect_fn"]

            connect_fn()

            # make a noop connect function in case this gets called again for some reason
            ctx.obj["brownie_connect_fn"] = lambda: None

        # check for private key in a file
        if value.endswith(".key"):
            # TODO: read an environment var to allow customizing this?
            key_dir = Path.home().joinpath(".argobytes/keys")

            # TODO: is this the mode that we want?
            assert key_dir.stat().st_mode == 0o40700, "key dir must be mode 0700"

            try:
                key_path = key_dir.joinpath(value)

                # check for secure permisions
                # TODO: is this the mode that we want?
                assert key_path.stat().st_mode == 0o100400, "key files must be mode 0400"

                account = accounts.add(key_path.read_text().strip())
            except Exception as e:
                self.fail(
                    f"Brownie could not load account from {value!r}: {e}",
                    param,
                    ctx,
                )
        elif value.endswith(".json"):
            print(f"Loading account @ {value}...")
            try:
                account = accounts.load(value)
            except Exception as e:
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


def with_dry_run(func, account, *args, tokens=None, confirm_delay_secs=6, **kwargs):
    """Run a function against a fork network and then confirm before doing it for real.

    since we have an account, the @brownie_connect() decorator isn't needed
    """
    import time

    from argobytes.tokens import print_start_and_end_balance

    assert account, "no account!"

    def do_func():
        with print_start_and_end_balance(account, tokens):
            func(account, *args, **kwargs)

    """
    # TODO: fork should check if we are already connected to a forked network and just use snapshots
    with fork(unlock=str(account)):
        do_func()
    """

    # prompt_for_confirmation(account)

    click.secho(
        f"\nI hope it did what you wanted on our forked net, because we are doing it for real in {confirm_delay_secs} seconds.\n\n",
        fg="red",
    )
    click.secho("[Ctrl C] to cancel", blink=True, bold=True, fg="red")
    time.sleep(confirm_delay_secs)

    do_func()

    print("transactions complete!")
