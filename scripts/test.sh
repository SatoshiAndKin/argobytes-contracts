#!/bin/sh -e

# TODO" enter the virtualenv and set flags so ganache-cli doesn't OOM
[ -n "$VIRTUAL_ENV" ]

# run the tests against the proper network with concurrency
# TODO: run with -n2 when ganache-cli doesn't have so many issues with OOMing
brownie test --network mainnet-fork
