#!/bin/sh
# deploy our contracts to a node started by `./scripts/staging-ganache.sh`

set -eux

[ -d contracts ]

rm -rf build/deployments/

BURN_GAS_TOKEN=0 ./venv/bin/brownie run dev-deploy --network staging
