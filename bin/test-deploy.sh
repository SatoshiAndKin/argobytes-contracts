#!/bin/sh
# deploy all our contracts to a temporary ganache instance
# the instance is shut down at the end of this script. This is just for testing dev-deploy.

set -eux

[ -d contracts ]

# we could let run compile for us, but the error messages (if any) aren't as easy to read
./venv/bin/brownie compile

export EXPORT_ARTIFACTS=0

./venv/bin/brownie run deploy/dev --network mainnet-fork "$@"
