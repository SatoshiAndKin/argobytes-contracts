#!/bin/sh -eu
# start ganache on port 8555
# you need a local node running with websockets available on port 8546
# set FORK_PROTO to "http" or "ws" (ws default)
# set FORK_HOST to the host where you are running an ethereum node (localhost default)
# set FORK_PORT to the http or ws port of the node on FORK_HOST (8546 default)
# set FORK_AT to a block you want to fork from. Useful when using beamsync. (latest default)

[ -z "${NODE_OPTIONS:-}" ] && echo "If ganache-cli crashes, try setting NODE_OPTIONS in your .env and then '. ./scripts/activate'"

fork="${FORK_PROTO:-ws}://${FORK_HOST:-localhost}:${FORK_PORT:-8546}@${FORK_AT:-10732284}"

set -x

exec ganache-cli \
    --accounts 10 \
    --hardfork istanbul \
    --fork "$fork" \
    --gasLimit 12000000 \
    --mnemonic "opinion adapt negative bone suit ill fossil alcohol razor script damp fold" \
    --port 8555 \
    --verbose \
    --networkId 1 \
    "$@" \
;
    # TODO: do we want this? it makes it work more like geth, but also makes debugging annoying
    # --noVMErrorsOnRPCResponse \
