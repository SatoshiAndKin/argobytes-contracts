#!/bin/sh

set -eux

[ -d contracts ]

rm -rf build/deployments/

BURN_GAS_TOKEN=0 ./venv/bin/brownie run dev-deploy --network staging
