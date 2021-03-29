import click

from argobytes import debug_shell
from brownie import chain


@click.command()
def tx_info():
    """Inspect transactions."""
    # TODO: use click features
    while True:
        try:
            tx_id = input("tx id (ctrl+d to exit): ")
        except EOFError:
            break

        print_tx_info(tx_id)

    print("\n\nGoodbye!")


def print_tx_info(tx):
    tx = chain.get_transaction(tx)

    print()
    tx.info()

    print()
    tx.call_trace()

    if tx.status == 0:
        # revert!
        print()
        tx.traceback()

    print()
    print("Sometimes useful, but often slow: tx.trace")
    print()
    print("[ctrl+d] to check another transaction")
    print()

    debug_shell(locals())
