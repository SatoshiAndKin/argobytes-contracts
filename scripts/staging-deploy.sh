#!/bin/sh

set -eux

[ -d contracts ]

rm -rf build/deployments/

./venv/bin/brownie run dev-deploy --network staging
