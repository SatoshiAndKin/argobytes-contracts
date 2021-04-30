import os

import click
import click_log
from click_plugins import with_plugins
from importlib_metadata import entry_points

from ..cli_helpers_lite import BROWNIE_ACCOUNT, brownie_connect, gas_choices, logger
from .compilers import compilers
from .tx import tx


@with_plugins(entry_points()["argobytes.plugins"])
@click.group()
@click_log.simple_verbosity_option(logger)
@click.option("--etherscan-token", default="", envvar="ETHERSCAN_TOKEN")
@click.option("--flashbot-account", default=None, type=BROWNIE_ACCOUNT)
@click.option("--gas-speed", default="standard", type=gas_choices, show_default=True)
@click.option("--gas-max-speed", default="rapid", type=gas_choices, show_default=True)
@click.option("--gas-increment", default=1.125, show_default=True)
@click.option("--gas-block-duration", default=2, show_default=True)
@click.option("--network", default=None, type=str, show_default=True)
@click.pass_context
@click.version_option()
def cli(
    ctx,
    etherscan_token,
    flashbot_account,
    gas_speed,
    gas_max_speed,
    gas_increment,
    gas_block_duration,
    network,
):
    """Ethereum helpers."""
    from .cli_logic import cli

    cli(
        ctx,
        etherscan_token,
        flashbot_account,
        gas_speed,
        gas_max_speed,
        gas_increment,
        gas_block_duration,
        network,
    )


@cli.command()
@click.pass_context
@brownie_connect()
def console(ctx):
    """Interactive shell."""
    from .cli_logic import console

    console(ctx)


@cli.command()
@brownie_connect()
def noop():
    """Do nothing but import the project (helpful for setup)."""
    pass


# TODO: write this
"""
@cli.command()
@click.option("command")
@click.pass_context
@brownie_connect()
def run(ctx):
    ""Run a simple command (UNDER CONSTRUCTION).""
    raise NotImplemented
"""


@cli.command()
@brownie_connect()
def donate():
    """Donate ETH or tokens to the developers.

    This project uses code written by an almost uncountable number of people. Donations are welcome.

    <https://gitcoin.co/eth-brownie>
    <https://donate.pypi.org/>
    """
    from .cli_logic import donate

    donate()


cli.add_command(compilers)
cli.add_command(tx)


def main():
    """Run the click app."""
    click_log.basic_config(logger)

    # https://click.palletsprojects.com/en/7.x/exceptions/#what-if-i-don-t-want-that
    # TODO: do we need this for easier testing? or is invoke catch_exceptions=False enough?
    standalone_mode = os.environ.get("ARGOBYTES_CLICK_STANDALONE", "1") == "1"

    cli(
        obj={},
        auto_envvar_prefix="ARGOBYTES",
        prog_name="argobytes",
        standalone_mode=standalone_mode,
    )
