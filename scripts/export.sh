#!/bin/bash -eux
# Export the latest contract ABIs
# Usage: ./scripts/export.sh 

ARGOBYTES_BACKEND_DIR=../argobytes-backend

[ -e "$ARGOBYTES_BACKEND_DIR" ]

ARGOBYTES_ABI_DIR="$ARGOBYTES_BACKEND_DIR/contracts/abi/argobytes"
ADDR_DIR="$ARGOBYTES_BACKEND_DIR/contracts/addr"

mkdir -p "$ARGOBYTES_ABI_DIR"
mkdir -p "$ADDR_DIR"

function export_argobytes_abi() {
    jq ".abi" "build/contracts/$1.json" > "$ARGOBYTES_ABI_DIR/$1.json"
}

./venv/bin/brownie compile

# we don't need to export all abis. we just need the abi's for our contracts
export_argobytes_abi AbstractERC20Exchange
export_argobytes_abi ArgobytesAtomicTrade
export_argobytes_abi ArgobytesOwnedVault
export_argobytes_abi CurveFiAction
export_argobytes_abi ExampleAction
export_argobytes_abi KyberAction
export_argobytes_abi OneSplitOffchainAction
export_argobytes_abi SynthetixDepotAction
export_argobytes_abi UniswapV1Action
export_argobytes_abi Weth9Action

# we do want all the addresses tho
cp "build/deployments/quick_and_dirty/"*".addr" "$ADDR_DIR/"
