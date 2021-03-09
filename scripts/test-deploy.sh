#!/bin/sh
# deploy all our contracts to a temporary ganache instance
# the instance is shut down at the end of this script. This is just for testing dev-deploy.

set -eux

[ -d contracts ]

# we could let run compile for us, but the error messages (if any) aren't as easy to read
./venv/bin/brownie compile

export FREE_GAS_TOKEN=${FREE_GAS_TOKEN:-0}
export EXPORT_ARTIFACTS=0

export MINT_GAS_TOKEN=${MINT_GAS_TOKEN:-$FREE_GAS_TOKEN}

./venv/bin/brownie run dev-deploy --network mainnet-fork "$@"
