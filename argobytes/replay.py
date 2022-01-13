from brownie import chain, network, rpc, web3
from brownie._config import CONFIG

from argobytes.cli_helpers_lite import prompt_loud_confirmation


def get_upstream_rpc() -> str:
    if is_forked_network():
        forked_host = CONFIG.active_network["cmd_settings"]["fork"]
        assert forked_host.startswith("http"), "only http supported for now"
        return forked_host

    return CONFIG.active_network["host"]


def is_forked_network() -> bool:
    return network.show_active().endswith("-fork")


def replay_history_on_main(automatic=False, history_start_index=0):
    main_rpc = get_upstream_rpc()
    return replay_history(
        main_rpc, automatic=automatic, history_start_index=history_start_index
    )


def replay_history(new_rpc, automatic=False, history_start_index=0):
    return replay_transactions(
        new_rpc, network.history[history_start_index:], automatic=automatic
    )


def replay_transactions(new_rpc, txs, automatic=False) -> None:
    raise NotImplementedError("this doesn't work right")

    # you probably want to use with_dry_run instead. this replays the exact same transactions which might be stale
    network.history.wait()

    old_rpc = web3.provider.endpoint_uri

    # disable snapshotting
    # TODO: we need this somewhere else, too
    old_snapshot = rpc.snapshot
    rpc.snapshot = lambda: 0

    old_sleep = rpc.sleep
    rpc.sleep = lambda _: 0

    network.history.clear()
    chain._network_disconnected()
    web3.connect(new_rpc)
    web3.reset_middlewares()

    if not automatic:
        # TODO: get accounts from txs
        prompt_loud_confirmation(None)

    # TODO: only replay from a specific address
    for tx in txs:
        # TODO: what happens if we do this on a tx sent by an unlocked account?
        # TODO: get the actual Contract for this so brownie's info is better?
        # TODO: if we set gas_limit and allow_revert=False, how does it check for revert?
        # TODO: are we sure required_confs=0 is always going to be okay?
        # TODO: are the nonces right here?
        # TODO: only replay transactions for a specific sender?
        tx.sender.transfer(
            to=tx.receiver,
            data=tx.input,
            allow_revert=False,
            required_confs=1,
        )

    network.history.wait()
    chain._network_disconnected()

    # put the old rpc back
    network.history.clear()
    chain._network_disconnected()
    web3.connect(old_rpc)
    web3.reset_middlewares()

    # restore snapshotting
    rpc.snapshot = old_snapshot
    rpc.sleep = old_sleep
