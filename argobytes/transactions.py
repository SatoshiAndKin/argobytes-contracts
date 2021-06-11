import atexit
import shelve
import shutil
import threading
from pathlib import Path

import arrow
from brownie import chain, network
from brownie.network.transaction import Status

from .contracts import load_contract


def get_event_address(tx, event):
    if isinstance(event, str):
        event = tx.events[event]

    # TODO: there is event.address, but it is sometimes empty
    return event.address or tx.logs[event.pos[0]].address


def get_event_contract(tx, event):
    address = get_event_address(tx, event)

    return load_contract(address)


def fetch_transaction(txid, force=False):
    """Get a transaction from the blockchain."""

    # TODO: `tx = chain.get_transaction(txid)`?
    # tx = network.transaction.TransactionReceipt(txid)
    tx = chain.get_transaction(txid)

    assert tx.txid == txid, "bad transaction id!"

    # TODO: brownie should probably have an option to do this for us. make a github issue
    # get the contract for parsing events from logs
    try:
        load_contract(tx.receiver, force=force, block=tx.block_number)
    except Exception:
        # not all contracts have verified source code. we'll have to make due
        pass

    if tx.logs:
        for l in tx.logs:
            # get more contracts for parsing events from logs
            try:
                load_contract(l.address, force=force, block=tx.block_number)
            except Exception:
                # not all contracts have verified source code. we'll have to make due
                pass

    # TODO: if (unknown) events, try loading contracts for all subcalls?

    # now that the contracts with the relevant events are loaded, we can fetch the transaction and have complete data
    # we build the receipt directly since chain.get_transaction does some other work
    return network.transaction.TransactionReceipt(txid)


_tx_cache = None


def close_transaction_cache():
    global _tx_cache
    if _tx_cache is None:
        return

    try:
        num_cached = len(_tx_cache)
    except ValueError:
        # print("Already closed")
        pass
    else:
        print(f"Saving tx cache of {num_cached} items...")

        _tx_cache.close()


def get_transaction(txid, force=False):
    """Get a transaction from our cache or the blockchain."""
    get_transaction_cache()

    if isinstance(txid, int):
        txid = hex(txid)

    if force or txid not in _tx_cache:
        tx = fetch_transaction(txid)

        if tx.confirmations >= 6:
            # this is a threading.Event and can't be saved to the cache
            tx._confirmed = True

            _tx_cache[tx.txid] = tx
    else:
        tx = _tx_cache[txid]

        # put back the threading event. it's needed by some brownie functions
        # we know this confirmed since we only cache deeply confirmed transactions
        tx._confirmed = threading.Event()
        tx._confirmed.set()

    return tx


def get_transaction_cache():
    global _tx_cache
    if _tx_cache is None:
        atexit.register(close_transaction_cache)

        # TODO: move this tx cache into brownie and make it more durable
        tx_cache_path = Path.home().joinpath(".argobytes", "tx_cache.shelve")

        # TODO: rolling backups?
        if tx_cache_path.exists():
            now = int(arrow.utcnow().timestamp())
            backup_path = Path.home().joinpath(".argobytes", f"tx_cache.{now}.shelve")
            shutil.copy(tx_cache_path, backup_path)

        _tx_cache = shelve.open(str(tx_cache_path))

    return _tx_cache


def sync_tx_cache():
    global _tx_cache
    if _tx_cache is None:
        return

    _tx_cache.sync()


# TODO: context manager to do this automatically?
# TODO: where should this be?
def wait_for_confirmation(pending_txs, required_confs=1):
    if pending_txs:
        # wait for the last transaction to confirm (if it confirms, then all the previous ones have confirmed)
        # pending_txs[-1].wait(required_confs)

        for tx in pending_txs:
            # we wait for each one because that prints some extra info
            tx.wait(required_confs)

            # this isn't pending anymore!
            if tx.status == Status.Confirmed:
                # TODO: if debug verbosity, print the tx info
                continue

            tx.info()

            # TODO: return something special if there were reverts? exit if something reverted
            raise Exception(f"Transaction {tx.txid} reverted!")

        pending_txs = []

    return pending_txs
