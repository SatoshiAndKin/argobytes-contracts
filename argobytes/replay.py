from brownie import network, web3
from brownie._config import CONFIG


def get_upstream_rpc():
    active_network = CONFIG.active_network

    assert active_network["id"].endswith("-fork"), "must be on a forked network"

    forked_host = active_network["cmd_settings"]["fork"]
    assert forked_host.startswith("http"), "only http supported for now"

    return forked_host


def replay_history_on_main(history_start_index=0):
    main_rpc = get_upstream_rpc()
    return replay_history(main_rpc, history_start_index=history_start_index)


def replay_history(new_rpc, history_start_index=0):
    return replay_transactions(new_rpc, network.history[history_start_index:])


# TODO: i'm not sure we want this. these txs will be stale by at least some time. better to rebuild them with "with_dry_run"
def replay_transactions(new_rpc, txs):
    network.history.wait()

    old_rpc = web3.provider.endpoint_uri

    web3.connect(new_rpc)
    web3.reset_middlewares()

    # TODO: not sure we want this
    network.history.clear()

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

    # put the old rpc back
    web3.connect(old_rpc)
    web3.reset_middlewares()

    # TODO: not sure we want this
    network.history.clear()
