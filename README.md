# Argobytes Smart Contracts

Open source contracts for atomic trading. What's an Argobytes? It's a non-sense word that makes searching easy.

My initial goal is for atomic arbitrage, but these contracts can be used for combining all sorts of ethereum smart contract actions.

There are 3 main components: ArgobytesAtomicActions, ArgobytesOwnedVault, and Actions.

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

## ArgobytesAtomicActions

*OUTDATED*

This smart contract lets you borrow tokens in a [flash loan](https://kollateral.co/) and then chain together multiple actions. If one of them fails, all of them are cancelled.

Anyone can use this contract. This contract cannot be upgraded or turned off.

This contract is designed to be called from other contracts. While it is possible to call this contract directly from an account, ERC20 approvals are unsafe as anyone can call functions on it, so be very careful!

## ArgobytesOwnedVault

*OUTDATED*

This contract holds all the cryptocurrency that I am going to use for decentralized trading. It has two roles that are allowed to interact with it.

1. Admin - This role can add other admins, upgrade the contract, trade tokens, and withdraw tokens. The have full and complete control of the contract!
2. Trusted Arbitrager - This role is only allowed to call the `atomicArbitrage` function.

Most functions on this contract can optionally save on transaction fees by freeing [Liquid Gas Token](https://lgt.exchange/) (an improvement on [GasToken](https://gastoken.io)).

The `atomicArbitrage` function is the key part of this contract.

1. If the vault has enough tokens to start the arbitrage trade, it transfers them to the ArgobytesAtomicActions contract.
2. Then it calls `ArgobytesAtomicActions.atomicTrades`
   1. If the contract has enough tokens to do the actions, it starts doing them. Else, the contract borrows tokens from kollateral and then starts doing them.
   2. Each action passes tokens (and optionally ETH) to the next action until all actions are completed. If any action fails, the transaction reverts.
   3. Once all actions succeed, any tokens borrowed from kollateral are returned.
   4. Then any remaining tokens are returned to the vault
3. The contract checks to make sure that its balance increased. If it decreased, the transaction reverts.
4. Finally, gas tokens are freed to reduce our transaction fees

I originally planned to tokenize deposits into this contract. That would allow anyone to deposit funds and share in the arbitrage profits. However, I think it is better for people to instead put their tokens into one of the platforms supported by kollateral. This should be more profitable for everyone.

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
