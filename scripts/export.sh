#!/bin/bash -eux
# Export the latest contract ABIs
# Usage: ./scripts/export.sh 

ARGOBYTES_BACKEND_DIR=../argobytes-backend
ARGOBYTES_WEB_DIR=../argobytes-web

[ -e "$ARGOBYTES_BACKEND_DIR" ]
[ -e "$ARGOBYTES_WEB_DIR" ]

ARGOBYTES_BACKEND_CONTRACT_DIR="$ARGOBYTES_BACKEND_DIR/contracts"
ARGOBYTES_BACKEND_ADDR_DIR="$ARGOBYTES_BACKEND_CONTRACT_DIR/addr"
ARGOBYTES_WEB_CONTRACT_DIR="$ARGOBYTES_WEB_DIR/src/contracts/data"
ARGOBYTES_WEB_ADDR_DIR="$ARGOBYTES_WEB_DIR/src/contracts/addr"

mkdir -p "$ARGOBYTES_BACKEND_CONTRACT_DIR"
mkdir -p "$ARGOBYTES_BACKEND_ADDR_DIR"
mkdir -p "$ARGOBYTES_WEB_CONTRACT_DIR"
mkdir -p "$ARGOBYTES_WEB_ADDR_DIR"

function export_argobytes_contract() {
    cp "build/contracts/$1.json" "$ARGOBYTES_BACKEND_CONTRACT_DIR/$1.json"

    cp "$ARGOBYTES_BACKEND_CONTRACT_DIR/$1.json" "$ARGOBYTES_WEB_CONTRACT_DIR/$1.json"
}

function export_brownie_contract() {
    contract_filename="$(basename "$1").json"

    cp "$HOME/.brownie/packages/$1.json" "$ARGOBYTES_BACKEND_CONTRACT_DIR/$contract_filename"

    cp "$ARGOBYTES_BACKEND_CONTRACT_DIR/$contract_filename" "$ARGOBYTES_WEB_CONTRACT_DIR/$contract_filename"
}

function export_interface() {
    cp "build/interfaces/$1.json" "$ARGOBYTES_BACKEND_CONTRACT_DIR/$1.json"

    cp "$ARGOBYTES_BACKEND_CONTRACT_DIR/$1.json" "$ARGOBYTES_WEB_CONTRACT_DIR/$1.json"
}

./venv/bin/brownie compile

# we don't need to export all contract jsons. we just need the one's for contracts that we expect to call
export_argobytes_contract ArgobytesActor
export_argobytes_contract ArgobytesAuthority
export_argobytes_contract ArgobytesLiquidGasTokenUser
export_argobytes_contract ArgobytesProxy
export_argobytes_contract ArgobytesFactory
export_argobytes_contract ArgobytesTrader

export_argobytes_contract ILiquidGasToken

export_argobytes_contract CurveFiAction
export_argobytes_contract ExampleAction
export_argobytes_contract KyberAction
export_argobytes_contract OneSplitOffchainAction
export_argobytes_contract SynthetixDepotAction
export_argobytes_contract UniswapV1Action
export_argobytes_contract UniswapV2Action
export_argobytes_contract Weth9Action

# TODO: make sure this matches the version in brownie-config.yaml!
export_brownie_contract "OpenZeppelin/openzeppelin-contracts@3.2.1-solc-0.7/build/contracts/ERC20"

export_interface "YearnWethVault"

# export all the addresses we know
# this lets us keep one address list here instead of 
# TODO: it would be nice to use build/deployments/map.json
cp "build/deployments/quick_and_dirty/"*".json" "$ARGOBYTES_BACKEND_ADDR_DIR/"
cp "build/deployments/quick_and_dirty/"*".json" "$ARGOBYTES_WEB_ADDR_DIR/"
