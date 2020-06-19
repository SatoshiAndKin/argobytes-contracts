# Argobytes Contracts (Brownie)

Open source contracts for atomic trading.

My initial use for these is for atomic arbitrage, but `ArgobytesAtomicTrade.sol` can be useful for combining all sorts of actions.


# Install

1. Install `geth` (or another node that is compatible with `ganache-cli --fork`). [Read this](https://gist.github.com/WyseNynja/89179917d209d10e6ea27c5f2f8f88f1).
2. Install `python3-dev` and `python3-venv`
3. Install `node` v12 (and `npm` v6) (I like to use [`nvm`](https://github.com/nvm-sh/nvm) to manage node versions)
4. Install `yarn` (`npm install -g yarn`)
5. Make a `.env` file:
    ```
    # We use etherscan for fetching mainnet contract data
    export ETHERSCAN_TOKEN=XXX
    # Tracing transactions in ganache can use a lot more than the default 1.7GB
    export NODE_OPTIONS="--max-old-space-size=8096"
    ```
6. Run `./scripts/setup.sh`
7. Run `./venv/bin/brownie networks import brownie-network-config.yaml True`


# Develop

Run:

    . ./scripts/activate

    brownie compile

    # test development deploy scripts
    # burning gastoken makes the script take a lot longer and cost more total gas, but it ends up costing less ETH
    # make sure nothing is using localhost:8575 before running this command!
    BURN_GAS_TOKEN=1 ./scripts/test-deploy.sh
    BURN_GAS_TOKEN=0 ./scripts/test-deploy.sh

    # have brownie setup a ganache and run unit tests
    # make sure nothing is using localhost:8565 before running this command!
    ./scripts/test.sh

    # run ganache forking mainnet at localhost:8555 (http or websocket)
    # i point my arbitrage finding code (in a seperate repo) at this node
    ./scripts/staging-ganache.sh

    # deploy this project's contracts to staging-ganache
    # this sets BURN_GAS_TOKEN=0 since speed is more important than saving development ETH
    ./scripts/staging-deploy.sh

    # export contract abi .jsons and deployed addresses to ../argobytes-backend/contracts/
    ./scripts/export.sh

    # interact with the contracts from a fun interface
    ./scripts/eth95.sh


# Upgrading dependencies

Run:

    pipx install pip-tools

    pip-compile --upgrade
    pip install -U -r requirements.txt
    yarn upgrade


# Reading

- <https://blog.ricmoo.com/wisps-the-magical-world-of-create2-5c2177027604>
