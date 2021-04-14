from brownie import chain, network

from argobytes.cli_helpers import COMMON_HELPERS, brownie_connect, debug_shell, logger
from argobytes.contracts import load_contract


def tx_info(txid):
    """Inspect transactions."""
    print_tx_info(txid)


def tx_loop():
    """Inspect multiple transactions."""
    # TODO: use click features
    while True:
        try:
            tx_id = input("tx id (ctrl+d to exit): ")
        except EOFError:
            break

        print_tx_info(tx_id)

    print("\n\nGoodbye!")


def print_tx_info(tx, call_trace=False):
    tx = chain.get_transaction(tx)

    # sometimes logs don't parse
    # TODO: brownie should probably handle this for us
    if len(tx.events) != len(tx.logs):
        for log in tx.logs:
            try:
                load_contract(log.address)
            except Exception as e:
                logger.warning(f"Unable to load contract @ {log.address}: {e}")

        tx = network.transaction.TransactionReceipt(tx.id)

    print()
    tx.info()

    if call_trace:
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

    extra_locals = COMMON_HELPERS
    extra_locals.update({"tx": tx})

    debug_shell(extra_locals)
