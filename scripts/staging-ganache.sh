#!/bin/sh -eu
# start ganache on port 8555
# you need a local node running with websockets available on port 8546

[ -z "${NODE_OPTIONS:-}" ] && echo "If ganache-cli crashes, try setting NODE_OPTIONS in your .env and then '. ./scripts/activate'"

# we default to using a local ethereum node
FORK_RPC="${FORK_RPC:-ws://localhost:8546}"

[ -n "${FORK_AT:-}" ] && FORK_RPC="${FORK_RPC}@${FORK_AT}"

set -x

exec ganache-cli \
    --accounts 10 \
    --hardfork istanbul \
    --fork "$FORK_RPC" \
    --host "0.0.0.0" \
    --gasLimit 12000000 \
    --mnemonic "opinion adapt negative bone suit ill fossil alcohol razor script damp fold" \
    --port 8555 \
    --verbose \
    --networkId 1 \
    "$@" \
;
    # TODO: do we want this? it makes it work more like geth, but also makes debugging annoying
    # --noVMErrorsOnRPCResponse \
