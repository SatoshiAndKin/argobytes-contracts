#!/bin/sh -e

# TODO" enter the virtualenv and set flags so ganache-cli doesn't OOM
[ -n "$VIRTUAL_ENV" ]

# run the tests against the proper network with concurrency
echo brownie test --network mainnet-fork -n 2
