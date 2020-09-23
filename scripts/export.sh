#!/bin/bash -eux
# Export the latest contract ABIs
# Usage: ./scripts/export.sh 

ARGOBYTES_BACKEND_DIR=../argobytes-backend
ARGOBYTES_WEB_DIR=../argobytes-web

[ -e "$ARGOBYTES_BACKEND_DIR" ]
[ -e "$ARGOBYTES_WEB_DIR" ]

ARGOBYTES_BACKEND_ABI_DIR="$ARGOBYTES_BACKEND_DIR/contracts/abi"
ARGOBYTES_BACKEND_ADDR_DIR="$ARGOBYTES_BACKEND_DIR/contracts/addr"
ARGOBYTES_WEB_ABI_DIR="$ARGOBYTES_WEB_DIR/public/contracts/abi"
ARGOBYTES_WEB_ADDR_DIR="$ARGOBYTES_WEB_DIR/public/contracts/addr"

mkdir -p "$ARGOBYTES_BACKEND_ABI_DIR"
mkdir -p "$ARGOBYTES_BACKEND_ADDR_DIR"
mkdir -p "$ARGOBYTES_WEB_ABI_DIR"
mkdir -p "$ARGOBYTES_WEB_ADDR_DIR"

function export_argo_abi() {
    jq ".abi" "build/contracts/$1.json" > "$ARGOBYTES_BACKEND_ABI_DIR/$1.json"

    cp "$ARGOBYTES_BACKEND_ABI_DIR/$1.json" "$ARGOBYTES_WEB_ABI_DIR/$1.json"
}

function export_brownie_abi() {
    contract_name=$(basename "$1")

    jq ".abi" "$HOME/.brownie/packages/$1.json" > "$ARGOBYTES_BACKEND_ABI_DIR/$contract_name.json"

    cp "$ARGOBYTES_BACKEND_ABI_DIR/$contract_name.json" "$ARGOBYTES_WEB_ABI_DIR/$contract_name.json"
}

function export_interface() {
    jq ".abi" "build/interfaces/$1.json" > "$ARGOBYTES_BACKEND_ABI_DIR/$1.json"

    cp "$ARGOBYTES_BACKEND_ABI_DIR/$1.json" "$ARGOBYTES_WEB_ABI_DIR/$1.json"
}

./venv/bin/brownie compile

# we don't need to export all abis. we just need the abi's for our contracts
export_argo_abi ArgobytesAtomicActions
export_argo_abi ArgobytesOwnedVault
export_argo_abi IArgobytesDiamond
export_argo_abi ILiquidGasToken
export_argo_abi CurveFiAction
export_argo_abi ExampleAction
export_argo_abi KyberAction
export_argo_abi OneSplitOffchainAction
export_argo_abi SynthetixDepotAction
export_argo_abi UniswapV1Action
export_argo_abi UniswapV2Action
export_argo_abi Weth9Action

export_brownie_abi "OpenZeppelin/openzeppelin-contracts@3.0.1/build/contracts/ERC20"

export_interface "YearnEthVault"

# we do want all the addresses tho
# TODO: it would be nice to uuse build/deployments/map.json, but that doesn't handle our curve action (though we should maybe improve how the curve action works)
cp "build/deployments/quick_and_dirty/"*".addr" "$ARGOBYTES_BACKEND_ADDR_DIR/"
cp "build/deployments/quick_and_dirty/"*".addr" "$ARGOBYTES_WEB_ADDR_DIR/"
