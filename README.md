# Argobytes Smart Contracts

What's an Argobytes? It's a non-sense word that makes searching easy. I'll probably rename it.

The initial use of these contracts is atomic arbitrage, but they can be used for combining all sorts of ethereum smart contract functions.

There are many components: ArgobytesProxy, ArgobytesActor, ArgobytesTrader, ArgobytesAuthority, ArgobytesFactory, and a bunch Actions.

## ArgobytesProxy

The proxy is a very lightweight contract that uses "delegatecall" to use another contract's logic but with its own state and balances. Anyone can deploy a contract with new logic and then anyone else can use it through their proxy.

The other contract will have **complete control** of the proxy's state and balances, so the proxy must only ever call trusted contracts!

The proxy has an immutable owner. By default, only the owner can use the proxy.

Owners can opt into more advanced authentication that lets them approve other addresses to call specific functions on specific contracts. Done properly, this allows for some very powerful features.

A common pattern will be sending one setup transaction that calls `approve` on an ERC-20 token for the proxy. Then sending a second transaction that calls the Proxy's `execute` function with another contract's address and calldata. The other contract will then transfer that ERC-20 token to make money somehow, and then return the proceeds to the owner.

## ArgobytesActor

Calling just one function on another contract isn't very exciting; you can already do that with your EOA. The Actor contract's `callActions` function takes a list of multiple contract addresses and functions. If any fail, the whole thing reverts.

This contract is a key part of other contracts. It probably won't be deployed by itself.

## ArgobytesTrader

Most sets of actions will probably involve trading tokens. The Trader's `atomicTrade` function uses ERC-20 approvals and ArgobytesActor to transfer and trade tokens. This can be helpful for aggregating trades across multiple exchanges.

The Trader's `*Arbitrage` functions are designed so that unless the trade completes with a positive arbitrage, the entire transaction reverts. This means that you can approve other people or contracts to trade with your balances. `atomicArbitrage` uses your own funds to do the arbitrage. `dydxFlashArbitrage` uses a (nearly) free flash loan from dYdX to do the arbitrage.

## ArgobytesAuthority

A surprisingly simple, but hopefully powerful way to authorize other contracts to use your proxy. For each authorization, you specify an addresses to call a specific function on a specific contract. Approval can be revoked at any time. Given a properly designed contract this should allow you to safely delegate permissions to others without them having custody of your funds.

## ArgobytesFactory

The Factory contract can be used to deploy any other contract as well as clones of the Proxy contract.

Every user needs their own proxy contract, but deploying it requires 672k gas. So instead, the proxy contract is deployed once. Then, the `cloneProxy` function is called to deploy a modified EIP-1167 proxy for only 69k gas. This proxy is hard coded to use the ArgobytesProxy contract for all its logic. It cannot be upgraded. If a new ArgobytesProxy is released, a new clone will need to be created. This is cheap though and so I think is far preferable to the complexity of upgradable contracts.

## Actions

The various "Action" contracts are for taking some sort of action on one or more of the many different projects available on Ethereum. The most common action is to trade one token for another.

- AbstractERC20Exchange: The common bits used by most any exchange that trades ERC20 tokens. It isn't necessary to use this, but it is helpful.
- ExampleAction: This action is just used for tests and isn't for mainnet. It can be a useful starting point when writing a new action.
- CurveFiAction: Trade tokens on <https://curve.fi>
- KyberAction: Trade tokens on <https://kyberswap.com>
- OneSplitOffchainAction: Split a trade across multiple decentralized exchanges. The route is calculated offchain because doing it onchain takes a lot of gas.
- SynthetixDepotAction: Trade ETH for sUSD on <https://synthetix.io>
- UniswapV1Action: Trade tokens on <https://v1.uniswap.exchange/>
- Weth9Action: [Wrap and unwrap ETH](https://weth.io/)

Lots more actions are in development. Anyone can write an action.

# Developing

## Initial setup

1. Get an account with <https://rivet.cloud> or <https://infura.io> or install `geth` (or another node that is compatible with `ganache-cli --fork`). [For geth, read this](https://gist.github.com/WyseNynja/89179917d209d10e6ea27c5f2f8f88f1).
2. Install `python3-dev` and `python3-venv`
3. Install `node` v14 (and `npm` v6) (I like to use [`nvm install 14`](https://github.com/nvm-sh/nvm))
4. Install `yarn` (`npm install -g yarn`)
5. Make a `.env` file:
    ```
    # We use etherscan for fetching mainnet contract data (https://etherscan.io/myapikey)
    export ETHERSCAN_TOKEN=XXX

    # URL for a mainnet Ethereum node (to fork at a specific block, append "@BLOCKNUM")
    export FORK_RPC="ws://localhost:8546"

    # Tracing transactions in ganache can use a lot more than the default 1.7GB
    export NODE_OPTIONS="--max-old-space-size=8096"
    ```
6. Run `./scripts/setup.sh`
7. Run `./venv/bin/brownie networks import brownie-network-config.yaml True`

## Development scripts

Run:

    . ./scripts/activate

    brownie compile

    # test development deploy scripts
    # burning gastoken makes the script take a lot longer and cost more total gas, but it ends up costing less ETH
    # make sure nothing is using localhost:8575 before running this command!
    FREE_GAS_TOKEN=1 ./scripts/test-deploy.sh
    FREE_GAS_TOKEN=0 ./scripts/test-deploy.sh

    # have brownie setup a ganache and run unit tests
    # make sure nothing is using localhost:8565 before running this command!
    ./scripts/test.sh

    # run ganache forking mainnet at localhost:8555 (http or websocket)
    # i point my arbitrage finding code (in a seperate repo) at this node
    ./scripts/staging-ganache.sh

    # deploy this project's contracts to staging-ganache
    # this sets FREE_GAS_TOKEN=0 since speed is more important than saving development ETH
    ./scripts/staging-deploy.sh

    # export contract abi .jsons and deployed addresses to ../argobytes-backend/contracts/
    # This is called automatically by `staging-deploy.sh`
    ./scripts/export.sh

    # interact with the contracts from a fun interface
    ./scripts/eth95.sh

## Upgrading dependencies

Run:

    pipx install pip-tools

    pip-compile --upgrade
    pip install -U -r requirements.txt
    yarn upgrade

# Thanks

This project wouldn't be possible without so many other projects.

- [Brownie](https://eth-brownie.readthedocs.io/en/stable/)
- [Solidity](https://solidity.readthedocs.io/)
- [Geth](https://github.com/ethereum/go-ethereum)
- [Kollateral](https://www.kollateral.co/)
- [Liquid Gas Token](https://lgt.exchange)
- [OpenZeppelin](https://openzeppelin.com/contracts)
- [Ganache-cli](https://github.com/trufflesuite/ganache-cli)
- [Etherscan](https://etherscan.io)
- and many others

# Reading

- <https://blog.ricmoo.com/wisps-the-magical-world-of-create2-5c2177027604>
