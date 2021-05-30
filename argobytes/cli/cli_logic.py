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
import os

import IPython
from brownie import network as brownie_network
from brownie import project, web3
from brownie.network import gas_price
from brownie.network.gas.strategies import GasNowScalingStrategy
from flashbots import flashbot

from argobytes.cli_helpers import COMMON_HELPERS, get_project_root
from argobytes.cli_helpers_lite import logger


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
    ctx.ensure_object(dict)

    # put this into the environment so that brownie sees it
    os.environ["ETHERSCAN_TOKEN"] = etherscan_token

    # TODO: set brownie autofetch_sources

    def brownie_connect():
        # this allows later click commands to set the default. there might be a better way
        network = ctx.obj["brownie_network"] or ctx.obj.get("default_brownie_network")

        # setup the project and network the same way brownie's run helper does
        brownie_project = project.load(get_project_root(), "ArgobytesBrownieProject")
        brownie_project.load_config()

        ctx.obj["brownie_project"] = brownie_project

        if network == "none" or network is None:
            logger.warning(f"{brownie_project._name} is the active project. Not connected to any networks")
        else:
            brownie_network.connect(network)

            logger.info(f"{brownie_project._name} is the active {network} project.")

            if flashbot_account:
                print(f"Using {flashbot_account} for signing flashbot bundles.")
                flashbot(web3, flashbot_account)

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
            elif network in ["bsc-main", "bsc-main-fork"]:
                gas_strategy = "5010000000"  # 5.01 gwei
                gas_price(gas_strategy)
                logger.info(f"Default gas price: {gas_strategy}")
            elif network in ["polygon", "polygon-fork"]:
                gas_strategy = "1010000000"  # "1.01 gwei"
                gas_price(gas_strategy)
                logger.info(f"Default gas price: {gas_strategy}")
            else:
                logger.warning("No default gas price or gas strategy has been set!")

    # pass the project on to the other functions
    ctx.obj["brownie_network"] = network
    ctx.obj["brownie_connect_fn"] = brownie_connect


def console(ctx):
    """Interactive shell."""
    IPython.start_ipython(argv=[], user_ns=COMMON_HELPERS)


def donate():
    """Donate ETH or tokens to the developers.

    This project uses code written by an almost uncountable number of people. Donations are welcome.

    <https://gitcoin.co/eth-brownie>
    <https://donate.pypi.org/>
    """
    web3.ens.resolve("tip.satoshiandkin.eth")
    raise NotImplementedError
