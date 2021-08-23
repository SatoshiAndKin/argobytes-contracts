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
    flashbot_account,
    gas_speed,
    gas_block_duration,
    gas_max_price,
    network,
):
    """Ethereum helpers."""
    ctx.ensure_object(dict)

    # put this into the environment so that brownie sees it
    os.environ["ETHERSCAN_TOKEN"] = etherscan_token

    # TODO: set brownie autofetch_sources

    def brownie_connect():
        from brownie.project.main import _install_dependencies

        # this allows later click commands to set the default. there might be a better way
        network = ctx.obj.get("brownie_network", ctx.obj.get("default_brownie_network"))

        project_root = get_project_root()

        _install_dependencies(project_root)

        # setup the project and network the same way brownie's run helper does
        brownie_project = project.load(project_root, "ArgobytesBrownieProject")
        brownie_project.load_config()

        ctx.obj["brownie_project"] = brownie_project

        if network == "none" or network is None:
            logger.warning("%s is the active project. Not connected to any networks", brownie_project._name)
        else:
            brownie_network.connect(network)

            logger.info("%s is the active %s project.", brownie_project._name, network)

            if flashbot_account:
                print(f"Using {flashbot_account} for signing flashbot bundles.")
                # flashbot(web3, flashbot_account)
                raise NotImplementedError

            # TODO: write my own gas strategy that uses the RPC's recommendation as a starting point
            # TODO: have it refresh this automatically
            recommended_gas = web3.eth.gasPrice
            logger.info("recommended gas: %s", recommended_gas)

            if network in [
                "mainnet", "mainnet-fork",
                "bsc-main", "bsc-main-fork",
                "polygon-main", "polygon-main-fork"
            ]:
                # TODO: use EIP1559 for mainnet/mainnet-fork
                gas_strategy = GasStrategyV1(
                    speed=gas_speed,
                    block_duration=gas_block_duration,
                    max_price=gas_max_price,
                )
                gas_price(gas_strategy)
                logger.info("Default gas strategy: %s", gas_strategy)
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
