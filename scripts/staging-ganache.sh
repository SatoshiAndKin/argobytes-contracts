#!/bin/sh

export NODE_OPTIONS="--max-old-space-size=16384"

exec ganache-cli \
    --accounts 10 \
    --hardfork istanbul \
    --fork https://eth.stytt.com \
    --gasLimit 6721975 \
    --mnemonic "opinion adapt negative bone suit ill fossil alcohol razor script damp fold" \
    --port 8565 \
    --verbose \
    --networkId 1 \
;
