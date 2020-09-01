#!/bin/sh -eux
# deploy our contracts to a node started by `./scripts/staging-ganache.sh`

FREE_GAS_TOKEN=${FREE_GAS_TOKEN:-0}
EXPORT_ARTIFACTS=${EXPORT_ARTIFACTS:-1}

export MINT_GAS_TOKEN=${MINT_GAS_TOKEN:-$FREE_GAS_TOKEN}

export FREE_GAS_TOKEN EXPORT_ARTIFACTS

[ -d contracts ]

rm -rf build/deployments/

./venv/bin/brownie run dev-deploy --network staging "$@"

if [ "$EXPORT_ARTIFACTS" = "1" ]; then
    ./scripts/export.sh
fi
