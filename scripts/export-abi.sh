#!/bin/bash -eux
# Usage: ./scripts/export-abi.sh ../argobytes-backend/contracts/abi/argobytes

DEST_DIR=$1

function export_abi() {
    jq ".abi" "build/contracts/$1.json" > "$DEST_DIR/$1.json"
}

./venv/bin/brownie compile

# we don't need to export everything
export_abi AbstractERC20Exchange
export_abi ArgobytesAtomicTrade
export_abi ArgobytesOwnedVault
export_abi CurveFiAction
export_abi ExampleAction
export_abi KyberAction
export_abi OneSplitOffchainAction
export_abi SynthetixDepotAction
export_abi UniswapV1Action
export_abi Weth9Action
