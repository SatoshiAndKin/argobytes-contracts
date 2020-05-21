#!/bin/sh

set -eux

[ -d contracts ]

# we could let run compile for us, but the error messages (if any) aren't as easy to read
./venv/bin/brownie compile

./venv/bin/brownie run dev-deploy --network mainnet-fork

