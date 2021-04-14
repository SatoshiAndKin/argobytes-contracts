import click

from argobytes.cli_helpers_lite import brownie_connect


@click.group()
def tx():
    """Inspect transactions."""


@tx.command(name="info")
@click.argument("txid")
@brownie_connect()
def tx_info(txid):
    """Inspect transactions."""
    from .tx_logic import tx_info

    tx_info()


@tx.command(name="loop")
@brownie_connect()
def tx_loop():
    """Inspect multiple transactions."""
    from .tx_logic import tx_loop

    tx_loop()
