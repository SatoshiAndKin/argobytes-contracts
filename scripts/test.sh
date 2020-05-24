#!/bin/sh -ex
# Run unit tests

# TODO" enter the virtualenv and set flags so ganache-cli doesn't OOM
if [ -z "$VIRTUAL_ENV" ]; then
  echo "please 'source scripts/activate' and then try again"
  exit 9
fi

# run the tests against the proper network with concurrency
# TODO: run with -n2 when ganache-cli doesn't have so many issues with OOMing
brownie test --network mainnet-fork "$@"
