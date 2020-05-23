# Argobytes Contracts (Brownie)

Open source contracts for atomic trading.

My initial use for these is for atomic arbitrage, but `ArgobytesAtomicTrade.sol` can be useful for combining all sorts of actions.


# Install

1. Install `geth` (or another node that is compatible with `ganache-cli --fork`). [Read this](https://gist.github.com/WyseNynja/89179917d209d10e6ea27c5f2f8f88f1).
2. Install `python3-dev` and `python3-venv`
3. Install `node` v12 (and `npm` v6) (I like to use [`nvm`](https://github.com/nvm-sh/nvm) to manage node versions)
4. Make a `.env` file:
    ```
    # We use etherscan for fetching mainnet contract data
    export ETHERSCAN_TOKEN=XXX
    # Tracing transactions in ganache can use a lot more than the default 1.7GB
    export NODE_OPTIONS="--max-old-space-size=8096"
    ```
5. Run `./scripts/setup.sh`
6. Run `./venv/bin/brownie network import brownie-network-config.yaml True`


# Develop

Run:

    . ./scripts/activate

    brownie compile

    # test development deploy scripts
    # burning gastoken makes the script take a lot longer and cost more total gas, but it ends up costing less ETH
    BURN_GAS_TOKEN=1 ./scripts/test-deploy.sh
    BURN_GAS_TOKEN=0 ./scripts/test-deploy.sh

    # have brownie setup a ganache and run unit tests
    ./scripts/test.sh

    # run ganache forking mainnet
    # i point my arbitrage finding code (in a seperate repo) at this node
    ./scripts/staging-ganache.sh

    # deploy this project's contracts to staging-ganache
    # this sets BURN_GAS_TOKEN=0 since speed is more important than saving development ETH
    ./scripts/staging-deploy.sh

    # export contract abi .jsons to a directory
    ./scripts/export-abi.sh ../argobytes-backend/contracts/abi/argobytes


# Upgrading dependencies

Run:

    pipx install pip-tools

    pip-compile --upgrade
    pip install -U -r requirements.txt
    npm upgrade
