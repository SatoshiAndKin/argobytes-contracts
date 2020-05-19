#!/bin/sh

set -eux

[ -d contracts ]

rm -rf build/deployments/

brownie run dev_deploy --network staging

