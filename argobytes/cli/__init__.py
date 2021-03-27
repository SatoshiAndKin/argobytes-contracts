"""
There are lots of ways to manage Ethereum account keys.

Our scripts will usually want two addresses:
    1. hardware wallet (ledger or trezor) account requiring user interaction
        - ledger
        - trezor
    2. local account that can be automated
        - brownie account
        - address without a key for read-only access
        - mnemonic and hd path

This entrypoint will handle setting these accounts up and then starting brownie.
"""
import logging
import sys
import os

import click
import click_log
from brownie import accounts, project, network as brownie_network, web3
from brownie._cli.console import Console
from brownie.network import gas_price
from brownie.network.gas.strategies import GasNowScalingStrategy
from click_plugins import with_plugins
from pathlib import Path
from pkg_resources import iter_entry_points

# from brownie.utils import fork

from argobytes import print_start_and_end_balance, print_token_balances
from argobytes.cli_helpers import get_project_root, logger
from argobytes.contracts import get_or_create, get_or_clone
from argobytes.tokens import load_token_or_contract


gas_choices = click.Choice(["slow", "standard", "fast", "rapid"])


@with_plugins(iter_entry_points("argobytes.plugins"))
@click.group()
@click_log.simple_verbosity_option(logger)
@click.password_option("--etherscan-token", envvar="ETHERSCAN_TOKEN")
@click.option("--gas-speed", default="standard", type=gas_choices, show_default=True)
@click.option("--gas-max-speed", default="rapid", type=gas_choices, show_default=True)
@click.option("--gas-increment", default=1.125, show_default=True)
@click.option("--gas-block-duration", default=2, show_default=True)
@click.option("--network", default="mainnet-fork", show_default=True)
@click.pass_context
@click.version_option()
def cli(
    ctx,
    etherscan_token,
    gas_speed,
    gas_max_speed,
    gas_increment,
    gas_block_duration,
    network,
):
    ctx.ensure_object(dict)

    # put this into the environment so that brownie sees it
    os.environ["ETHERSCAN_TOKEN"] = etherscan_token

    # setup the project and network the same way brownie's run helper does
    brownie_project = project.load(get_project_root())
    brownie_project.load_config()

    if network != "none":
        brownie_network.connect(network)

        logger.info(f"{brownie_project._name} is the active {network} project.")

        if network in ["mainnet", "mainnet-fork"]:
            # TODO: write my own strategy
            gas_strategy = GasNowScalingStrategy(
                initial_speed=gas_speed,
                max_speed=gas_max_speed,
                increment=gas_increment,
                block_duration=gas_block_duration,
            )
            gas_price(gas_strategy)
            logger.info(f"Default gas strategy: {gas_strategy}")
        elif network in ["bsc", "bsc-fork"]:
            gas_strategy = "10 gwei"
            gas_price(gas_strategy)
            logger.info(f"Default gas price: {gas_strategy}")
        elif network in ["matic", "matic-fork"]:
            gas_strategy = "1 gwei"
            gas_price(gas_strategy)
            logger.info(f"Default gas price: {gas_strategy}")
        else:
            logger.warning("No default gas price or gas strategy has been set!")
    else:
        logger.warning(
            f"{brownie_project._name} is the active project. It is not conencted to any networks"
        )

    # pass the project on to the other functions
    ctx.obj["brownie_project"] = brownie_project


@cli.command()
@click.pass_context
def console(ctx):
    """Interactive shell."""
    shell = Console(project=ctx.obj["brownie_project"])
    shell.interact(banner="Argobytes environment is ready.", exitmsg="Goodbye!")


@cli.command()
def donate():
    """Donate ETH or tokens to the developers.

    This project uses code written by an almost uncountable number of people. Donations are welcome.

    <https://gitcoin.co/eth-brownie>
    <https://donate.pypi.org/>
    """
    who = web3.ens.resolve("tip.satoshiandkin.eth")
    raise NotImplementedError


def main():
    click_log.basic_config(logger)

    cli(obj={}, auto_envvar_prefix="ARGOBYTES")
