from brownie import chain, network, rpc, web3
from brownie._config import CONFIG


def get_upstream_rpc():
    if is_forked_network():
        forked_host = CONFIG.active_network["cmd_settings"]["fork"]
        assert forked_host.startswith("http"), "only http supported for now"
        return forked_host

    return CONFIG.active_network["host"]


def is_forked_network():
    return CONFIG.active_network["id"].endswith("-fork")


def replay_history_on_main(history_start_index=0):
    main_rpc = get_upstream_rpc()
    return replay_history(main_rpc, history_start_index=history_start_index)


def replay_history(new_rpc, history_start_index=0):
    return replay_transactions(new_rpc, network.history[history_start_index:])


def replay_transactions(new_rpc, txs):
    # you probably want to use with_dry_run instead. this replays the exact same transactions which might be stale
    network.history.wait()

    old_rpc = web3.provider.endpoint_uri

    # disable snapshotting
    rpc_singleton = rpc.Rpc()

    old_snapshot = rpc_singleton.snapshot
    rpc_singleton.snapshot = lambda: 0

    old_sleep = rpc_singleton.sleep
    rpc_singleton.sleep = lambda _: None

    network.history.clear()
    chain._network_disconnected()
    web3.connect(new_rpc)
    web3.reset_middlewares()

    # TODO: only replay from a specific address
    for tx in txs:
        # TODO: what happens if we do this on a tx sent by an unlocked account?
        # TODO: get the actual Contract for this so brownie's info is better?
        # TODO: if we set gas_limit and allow_revert=False, how does it check for revert?
        # TODO: are we sure required_confs=0 is always going to be okay?
        # TODO: are the nonces right here?
        tx.sender.transfer(
            to=tx.receiver,
            data=tx.input,
            gas_limit=tx.gas_limit,
            allow_revert=False,
            required_confs=0,
        )

    network.history.wait()
    chain._network_disconnected()

    # put the old rpc back
    network.history.clear()
    chain._network_disconnected()
    web3.connect(old_rpc)
    web3.reset_middlewares()

    # restore snapshotting
    rpc_singleton.snapshot = old_snapshot
    rpc_singleton.sleep = old_sleep
