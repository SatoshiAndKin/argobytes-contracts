# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`

import json
import os
from eth_utils import to_bytes
from eth_abi import encode_single, encode_abi
from brownie import *
from argobytes_util import *
from argobytes_mainnet import *


# TODO: set these inside main instead of using globals
# TODO: old versions of these contracts were cheaper to deploy with gas token. with less state, they are cheaper without gastoken though
# TODO: i think some of them might still be. investigate more
FREE_GAS_TOKEN = os.environ.get("FREE_GAS_TOKEN", "0") == "1"
MINT_GAS_TOKEN = FREE_GAS_TOKEN or os.environ.get("MINT_GAS_TOKEN", "0") == "1"
EXPORT_ARTIFACTS = os.environ.get("EXPORT_ARTIFACTS", "0") == "1"
DEPLOY_DIR = os.path.join(project.main.check_for_project('.'), "build", "deployments", "quick_and_dirty")

REQUIRE_GAS_TOKEN = FREE_GAS_TOKEN or os.environ.get("REQUIRE_GAS_TOKEN", "0") == "1"


def quick_save_contract(contract):
    quick_save(contract._name, contract.address)


def quick_save(contract_name, address):
    """quick and dirty way to save contract addresses in an easy to read format."""
    if EXPORT_ARTIFACTS == False:
        print(f"{contract_name} is deployed at {address}\n")
        return

    quick_name = contract_name + ".json"

    quick_path = os.path.join(DEPLOY_DIR, quick_name)

    print(f"Saving deployed address to {quick_path}")

    with open(quick_path, 'w') as opened_file:
        opened_file.write(json.dumps(address))


def main():
    os.makedirs(DEPLOY_DIR, exist_ok=True)

    print("account 0:", accounts[0])

    # gas price should be 3.0x to 3.5x the mint price
    # TODO: double check and document why its 3.5x
    expected_mainnet_mint_price = "20 gwei"
    # unless you are in a rush, it is better to not use gas token and just deploy at expected_mainnet_mint_price
    expected_mainnet_gas_price = "60 gwei"

    deadline = 90000000000000000000

    kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWalletAddress)

    # TODO: WARNING! SKI_METAMASK_1 is an admin role only for staging. this should be SKI_HARDWARE_1
    argobytes_proxy_owner = accounts[0]

    argobytes_proxy_arbitragers = [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    starting_balance = accounts[0].balance()

    def argobytes_factory_deploy_helper(factory, contract, *deploy_args):
        gas_token_amount = 0
        require_gas_token = False
        salt = ""

        deploy_tx = factory.deployAndFree(
            gas_token_amount,
            require_gas_token,
            salt,
            contract.deploy.encode_input(*deploy_args),
            to_bytes(hexstr="0x"),
            {
                "gas_price": expected_mainnet_gas_price,
            },
        )
        deployed = contract.at(deploy_tx.return_value, accounts[0])
        quick_save_contract(deployed)

        return deployed

    # TODO: docs for using ERADICATE2
    # TODO: openzepplin helper uses bytes32, but gastoken uses uint256.
    salt = ""
    salt_uint = 0

    gas_token = interface.ILiquidGasToken(LiquidGasTokenAddress, accounts[0])

    # we save the contract even if we aren't burning gas token here
    # still good to test that it works and we might use it outside this script
    quick_save_contract(gas_token)

    if FREE_GAS_TOKEN:
        gas_token_for_freeing = gas_token
    else:
        gas_token_for_freeing = "0x0000000000000000000000000000000000000000"

    # deploy a dsproxy just to compare gas costs
    # TODO: whats the deploy cost of DSProxyFactory?
    ds_proxy_factory = interface.DSProxyFactory(DSProxyFactoryAddress, accounts[5])
    ds_proxy_tx = ds_proxy_factory.build()

    # TODO: do this earlier and transfer the coins to the diamond_creator address before deployment
    # mint some gas token so we can have cheaper deploys for the rest of the contracts
    if MINT_GAS_TOKEN:
        deadline = 999999999999999
        num_mints = 16

        print("Minting gas_token for", accounts[0])

        # add some LGT liquidity
        # TODO: how many tokens should we mint? what size liquidity pool and at what price do we expect to see?
        # TODO: what should we set the price of LGT to?
        mint_batch_amount = 50
        for _ in range(0, num_mints):
            # TODO: im still not positive we want mintToLiqudity instead of mintTo
            # TODO: keep track of gas spent minting liquidity
            # gas_token.mintToLiquidity(mint_batch_amount, 0, deadline, accounts[0], {
            #                           'value': 1e19, "gasPrice": expected_mainnet_mint_price})
            gas_token.mintFor(mint_batch_amount, accounts[0], {"gasPrice": expected_mainnet_mint_price})

        gas_tokens_start = gas_token.balanceOf.call(accounts[0])

        print("Starting gas_token balance:", gas_tokens_start)

        assert gas_tokens_start == mint_batch_amount * num_mints

    # deploy ArgobytesFactory using LGT's create2 helper
    # when combined with a salt found by ERADICATE2, we can have an address with lots of 0 bytes
    if FREE_GAS_TOKEN:
        # TODO: calculate the optimal number of gas to buy
        free_num_gas_tokens = 19
    else:
        free_num_gas_tokens = 0

    deploy_tx = gas_token.create2(
        free_num_gas_tokens,
        deadline,
        salt_uint,
        ArgobytesFactory.deploy.encode_input(),
        {
            # TODO: i'm getting revert: insufficient ether even when setting gas_token_amount to 0 and value to 0
            # this ether will get sent back if gas_token_amount is 0
            # TODO: calculate an actual amount for this
            "value": "1 ether",
        }
    )
    # TODO: check how much we spent on gas token

    argobytes_factory = ArgobytesFactory.at(deploy_tx.return_value, accounts[0])
    quick_save_contract(argobytes_factory)
    # the ArgobytesFactory is deployed and ready for use!

    # let the proxy use our gas token
    if FREE_GAS_TOKEN:
        gas_token.approve(argobytes_factory, 2**256-1)

    # build an ArgobytesAuthority
    argobytes_authority = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesAuthority)

    # build an ArgobytesProxy to use for cloning
    argobytes_proxy = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesProxy)
    quick_save_contract(argobytes_proxy)

    # clone ArgobytesProxy for accounts[0]
    deploy_tx = argobytes_factory.deployClone(
        argobytes_proxy.address,
        salt,
        accounts[0],
        {
            "from": accounts[0],
            "gas_price": expected_mainnet_gas_price,
        },
    )

    argobytes_proxy_clone = ArgobytesProxy.at(deploy_tx.events['NewClone']['clone'], accounts[0])

    if FREE_GAS_TOKEN:
        gas_token.approve(argobytes_proxy_clone, -1)

    # TODO: setup auth for the proxy
    # for now, owner-only access works, but we need to allow a bot in to call atomicArbitrage

    # deploy the main contracts
    argobytes_trader = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesTrader)
    argobytes_actor = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesActor)
    argobytes_liquid_gas_token_user = argobytes_factory_deploy_helper(
        argobytes_factory, ArgobytesLiquidGasTokenUser)

    # deploy all the actions
    example_action = argobytes_factory_deploy_helper(argobytes_factory, ExampleAction)
    onesplit_offchain_action = argobytes_factory_deploy_helper(argobytes_factory, OneSplitOffchainAction)
    kyber_action = argobytes_factory_deploy_helper(argobytes_factory, KyberAction, accounts[0])
    uniswap_v1_action = argobytes_factory_deploy_helper(argobytes_factory, UniswapV1Action)
    uniswap_v2_action = argobytes_factory_deploy_helper(argobytes_factory, UniswapV2Action)
    # zrx_v3_action = argobytes_factory_deploy_helper(argobytes_factory, ZrxV3Action)
    weth9_action = argobytes_factory_deploy_helper(argobytes_factory, Weth9Action)
    synthetix_depot_action = argobytes_factory_deploy_helper(argobytes_factory, SynthetixDepotAction)
    curve_fi_action = argobytes_factory_deploy_helper(argobytes_factory, CurveFiAction)

    bulk_actions = [
        # allow bots to call argobytes_trader.atomicArbitrage
        # TODO: think about this more. the msg.sendere might not be what we need
        (
            argobytes_authority.address,
            argobytes_authority.allow.encode_input(
                argobytes_proxy_arbitragers,
                argobytes_trader.address,
                argobytes_trader.atomicArbitrage.signature,
            ),
            False,
        ),
        # register for kyber's fee program
        (
            KyberRegisterWalletAddress,
            kyber_register_wallet.registerWallet.encode_input(argobytes_proxy_owner),
            False,
        ),
        # TODO: gas_token.buyAndFree or gas_token.free depending on off-chain balance/price checks
    ]

    argobytes_proxy_clone.execute(
        argobytes_actor,
        argobytes_actor.callActions.encode_input(bulk_actions),
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price}
    )

    if FREE_GAS_TOKEN:
        # make sure we still have some gastoken left
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_proxy_owner)

        print("gas token:", gas_token.address)

        print("gas_tokens_remaining:", gas_tokens_remaining, "/", gas_tokens_start)

        assert gas_tokens_remaining > 0
        assert gas_tokens_remaining <= mint_batch_amount
    elif MINT_GAS_TOKEN:
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_proxy_owner)

        print("gas token:", gas_token.address)

        print("gas_tokens_remaining:", gas_tokens_remaining)

        assert gas_tokens_remaining > 0
    else:
        print("gas_tokens_remaining: N/A")

    print("gas used by accounts[0]:", accounts[0].gas_used)

    ending_balance = accounts[0].balance()

    assert ending_balance < starting_balance

    print("ETH used by accounts[0]:", (starting_balance - ending_balance) / 1e18)

    # save all the addresses we might use, not just ones for own contracts
    quick_save("CHI", CHIAddress)
    quick_save("CurveFiBUSD", CurveFiBUSDAddress)
    quick_save("CurveFiCompound", CurveFiCompoundAddress)
    quick_save("CurveFiPAX", CurveFiPAXAddress)
    quick_save("CurveFiREN", CurveFiRENAddress)
    quick_save("CurveFiSUSDV2", CurveFiSUSDV2Address)
    quick_save("CurveFiTBTC", CurveFiTBTCAddress)
    quick_save("CurveFiUSDT", CurveFiUSDTAddress)
    quick_save("CurveFiY", CurveFiYAddress)
    quick_save("GasToken2", GasToken2Address)
    quick_save("KollateralInvoker", KollateralInvokerAddress)
    quick_save("KyberNetworkProxy", KyberNetworkProxyAddress)
    quick_save("KyberRegisterWallet", KyberRegisterWalletAddress)
    quick_save("LiquidGasToken", LiquidGasTokenAddress)
    quick_save("OneSplit", OneSplitAddress)
    quick_save("SynthetixAddressResolver", SynthetixAddressResolverAddress)
    quick_save("UniswapFactory", UniswapV1FactoryAddress)
    quick_save("YearnWethVault", YearnWethVaultAddress)

    # TODO: this list is going to get long. use tokenlists.org instead
    quick_save("DAI", DAIAddress)
    quick_save("cDAI", cDAIAddress)
    quick_save("cUSDC", cUSDCAddress)
    quick_save("sUSD", ProxysUSDAddress)
    quick_save("USDC", USDCAddress)
    quick_save("COMP", COMPAddress)
    quick_save("AAVE", AAVEAddress)
    quick_save("LINK", LINKAddress)
    quick_save("MKR", MKRAddress)
    quick_save("SNX", SNXAddress)
    quick_save("WBTC", WBTCAddress)
    quick_save("YFI", YFIAddress)
    quick_save("WETH9", WETH9Address)
    quick_save("yvyCRV", YVYCRVAddress)

    # give the argobytes_proxy a bunch of coins. it will forward them when deploying the diamond
    accounts[1].transfer(DevHardwareAddress, 50 * 1e18)
    accounts[2].transfer(DevHardwareAddress, 50 * 1e18)
    accounts[3].transfer(DevHardwareAddress, 50 * 1e18)
    accounts[4].transfer(DevMetamaskAddress, 50 * 1e18)

    # make a clone vault w/ auth for accounts[5] and approve a bot to call atomicArbitrage. then print total gas
    starting_balance = accounts[5].balance()

    # TODO: gas golf deployClone function that uses msg.sender instead of owner in the calldata?
    deploy_tx = argobytes_factory.deployClone(
        argobytes_proxy.address,
        salt,
        accounts[5],
        {
            "from": accounts[5],
            "gas_price": expected_mainnet_gas_price,
        },
    )

    argobytes_proxy_clone_5 = ArgobytesProxy.at(deploy_tx.events['NewClone']['clone'], accounts[5])

    bulk_actions = [
        # allow bots to call argobytes_trader.atomicArbitrage
        # TODO: think about this more. the msg.sendere might not be what we need
        (
            argobytes_authority.address,
            argobytes_authority.allow.encode_input(
                argobytes_proxy_arbitragers,
                argobytes_trader.address,
                argobytes_trader.atomicArbitrage.signature,
            ),
            False,
        ),
        # TODO: gas_token.buyAndFree or gas_token.free depending on off-chain balance/price checks
    ]

    argobytes_proxy_clone_5.execute(
        argobytes_actor,
        argobytes_actor.callActions.encode_input(bulk_actions),
        {"gasPrice": expected_mainnet_gas_price}
    )

    ending_balance = accounts[5].balance()

    print("ETH used by accounts[5] to deploy a proxy with auth:", (starting_balance - ending_balance) / 1e18)

    # make a clone for accounts[6]. then print total gas
    starting_balance = accounts[6].balance()

    deploy_tx = argobytes_factory.deployClone(
        argobytes_proxy.address,
        salt,
        accounts[6],
        {
            "from": accounts[6],
            "gas_price": expected_mainnet_gas_price,
        },
    )

    ending_balance = accounts[6].balance()

    print("ETH used by accounts[6] to deploy a proxy:", (starting_balance - ending_balance) / 1e18)

    reset_block_time(synthetix_depot_action)

    # TODO: can we detect if brownie is running with -I?
    # assert False
