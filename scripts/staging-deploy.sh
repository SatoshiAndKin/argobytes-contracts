#!/bin/sh -eux
# deploy our contracts to a node started by `./scripts/staging-ganache.sh`

[ -d contracts ]

rm -rf build/deployments/

# we could let run compile for us, but the error messages (if any) aren't as easy to read
./venv/bin/brownie compile

export FREE_GAS_TOKEN=${FREE_GAS_TOKEN:-0}
export EXPORT_ARTIFACTS=${EXPORT_ARTIFACTS:-1}

export MINT_GAS_TOKEN=${MINT_GAS_TOKEN:-$FREE_GAS_TOKEN}

./venv/bin/brownie run dev-deploy --network staging "$@"

if [ "$EXPORT_ARTIFACTS" = "1" ]; then
    ./scripts/export.sh
fi
