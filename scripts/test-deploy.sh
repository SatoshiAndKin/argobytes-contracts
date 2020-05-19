#!/bin/sh

set -eux

[ -d contracts ]

# we could let run compile for us, but the error messages (if any) aren't as easy to read
brownie compile

brownie run dev_deploy --network mainnet-fork

