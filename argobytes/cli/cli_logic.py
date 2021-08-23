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
import time

from brownie import chain
from brownie import network as brownie_network
from brownie import project, web3
from brownie.network import gas_price

from argobytes.cli_helpers import get_project_root
from argobytes.cli_helpers_lite import logger
from argobytes.gas_strategy import GasStrategyV1

# from flashbots import flashbot


def cli(
    ctx,
    etherscan_token,
    gas_speed,
    gas_max_price,
    network,
):
    """Ethereum helpers."""
    from brownie.project.main import _install_dependencies

    ctx.ensure_object(dict)

    # put this into the environment so that brownie sees it
    # TODO: polygonscan and bscscan tokens?
    os.environ["ETHERSCAN_TOKEN"] = etherscan_token

    # TODO: set brownie autofetch_sources

    project_root = get_project_root()

    _install_dependencies(project_root)

    # setup the project and network the same way brownie's run helper does
    brownie_project = project.load(project_root, "ArgobytesBrownieProject")
    brownie_project.load_config()

    ctx.obj["brownie_project"] = brownie_project

    def brownie_connect():
        """Defer connecting to brownie as long as possible so that later commands can set the network."""
        if web3.isConnected():
            # aleady connnected
            return

        # this allows later click commands to set the default. there might be a better way
        # we do "or" because "brownie_network" might be set to None
        network = ctx.obj.get("brownie_network") or ctx.obj.get("default_brownie_network")

        if network == "none" or not network:
            logger.warning("%s is the active project. Not connected to any networks", brownie_project._name)
        else:
            brownie_network.connect(network)

            logger.info("%s is the active %s project.", brownie_project._name, network)

            # make sure the network is synced
            # TODO: how many seconds should we tolerate? different chains are different. maybe base on block time?
            # TODO: maybe query some central service?
            if web3.eth.syncing:
                raise RuntimeError("Node is syncing!")

            if chain[-1].timestamp < time.time() - 60:
                raise RuntimeError("block timestamp behind by more than 60 seconds!")

            if network in ["mainnet", "mainnet-fork", "bsc-main", "bsc-main-fork", "polygon-main", "polygon-main-fork"]:
                # TODO: use EIP1559 for mainnet/mainnet-fork (or maybe automatically somehow?)
                gas_strategy = GasStrategyV1(
                    speed=gas_speed,
                    max_price=gas_max_price,
                )
                gas_price(gas_strategy)
                logger.info(gas_strategy)
            else:
                logger.warning("No default gas price or gas strategy has been set!")

    # pass the project on to the other functions
    ctx.obj["brownie_network"] = network
    ctx.obj["brownie_connect_fn"] = brownie_connect


def donate():
    """Donate ETH or tokens to the developers.

    This project uses code written by an almost uncountable number of people. Donations are welcome.

    <https://gitcoin.co/eth-brownie>
    <https://donate.pypi.org/>
    """
    web3.ens.resolve("tip.satoshiandkin.eth")
    raise NotImplementedError
