# Argobytes Contracts (Brownie)

Open source contracts for atomic trading.

My initial use for these is for atomic arbitrage, but `ArgobytesAtomicTrade.sol` can be useful for combining all sorts of actions.


# Install

1. Install `python3-dev` and `python3-venv`
2. Install `node` v12 and `npm` v6 (I like to use `nvm` to manage node versions)
2. Run `./scripts/setup.sh`
3. Make a .env:

    export ETHERSCAN_TOKEN=XXX
    export NODE_OPTIONS="--max-old-space-size=16384"
    export WEB3_INFURA_PROJECT_ID=XXX


# Develop

Run:

    . ./scripts/activate

    brownie compile

    # test development deploy scripts
    ./scripts/test-deploy.sh

    # have brownie setup a ganache and run unit tests
    ./scripts/test.sh

    # run ganache forking mainnet 
    ./scripts/staging-ganache.sh

    # deploy to staging-ganache
    ./scripts/staging-deploy.sh

NOTE: You will want to edit ~/.brownie/network-config.yaml to point to a local node. Infura (the default) is really slow in forking mode.


# Upgrading dependencies

Run:

    . ./scripts/activate
    pip-compile --upgrade
    pip install -U -r requirements.txt
    npm upgrade
