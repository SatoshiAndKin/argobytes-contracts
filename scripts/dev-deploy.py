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

    # unless you are in a rush, it is better to not use gas token and just deploy at expected_mainnet_mint_price
    expected_mainnet_gas_price = "120 gwei"

    deadline = 90000000000000000000

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

    def argobytes_factory_deploy_helper(
        factory,
        contract,
        deployer=accounts[0],
        gas_price=expected_mainnet_gas_price,
        constructor_args=[],
        extra_hexstr="0x",
        salt="",
    ):
        deploy_tx = factory.createContract(
            salt,
            contract.deploy.encode_input(*constructor_args),
            to_bytes(hexstr=extra_hexstr),
            {
                "gas_price": expected_mainnet_gas_price,
                "from": deployer,
            },
        )

        deployed = contract.at(deploy_tx.return_value, deployer)
        quick_save_contract(deployed)

        return deployed

    # TODO: docs for using ERADICATE2
    # TODO: openzepplin helper uses bytes32, but gastoken uses uint256.
    salt = ""
    salt_uint = 0

    # deploy a dsproxy just to compare gas costs
    # TODO: whats the deploy cost of DSProxyFactory?
    ds_proxy_factory = interface.DSProxyFactory(DSProxyFactoryAddress, accounts[5])
    ds_proxy_tx = ds_proxy_factory.build()

    # deploy ArgobytesFactory using LGT's create2 helper
    # when combined with a salt found by ERADICATE2, we can have an address with lots of 0 bytes
    # TODO: originally i wanted to use gastoken, but i'm really seeing it now as pollution. their create2 helper is still helpful though
    """
    deploy_tx = gas_token.create2(
        0,
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
    """
    argobytes_factory = accounts[0].deploy(ArgobytesFactory)

    quick_save_contract(argobytes_factory)
    # the ArgobytesFactory is deployed and ready for use!

    # build an ArgobytesAuthority
    argobytes_authority = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesAuthority)

    # build an ArgobytesFlashBorrower to use for cloning
    argobytes_proxy = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesFlashBorrower)
    quick_save_contract(argobytes_proxy)

    # clone ArgobytesFlashBorrower for accounts[0]
    clone_tx = argobytes_factory.createClone(
        argobytes_proxy,
        salt,
        accounts[0],
        {
            "from": accounts[0],
            "gas_price": expected_mainnet_gas_price,
        },
    )

    argobytes_proxy_clone = ArgobytesFlashBorrower.at(clone_tx.return_value, accounts[0])

    # TODO: setup auth for the proxy
    # for now, owner-only access works, but we need to allow a bot in to call atomicArbitrage

    # deploy the main contracts
    argobytes_multicall = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesMulticall)

    # deploy base actions
    argobytes_trader = argobytes_factory_deploy_helper(argobytes_factory, ArgobytesTrader)

    # deploy all the exchange actions
    example_action = argobytes_factory_deploy_helper(argobytes_factory, ExampleAction, gas_price=0)
    # onesplit_offchain_action = argobytes_factory_deploy_helper(argobytes_factory, OneSplitOffchainAction)
    kyber_action = argobytes_factory_deploy_helper(argobytes_factory, KyberAction, constructor_args=[accounts[0]])
    uniswap_v1_action = argobytes_factory_deploy_helper(argobytes_factory, UniswapV1Action)
    uniswap_v2_action = argobytes_factory_deploy_helper(argobytes_factory, UniswapV2Action)
    # zrx_v3_action = argobytes_factory_deploy_helper(argobytes_factory, ZrxV3Action)
    weth9_action = argobytes_factory_deploy_helper(argobytes_factory, Weth9Action)
    # synthetix_depot_action = argobytes_factory_deploy_helper(argobytes_factory, SynthetixDepotAction)
    curve_fi_action = argobytes_factory_deploy_helper(argobytes_factory, CurveFiAction)

    # deploy leverage cyy3crv actions
    enter_cyy3crv_action = argobytes_factory_deploy_helper(argobytes_factory, EnterCYY3CRVAction)
    exit_cyy3crv_action = argobytes_factory_deploy_helper(argobytes_factory, ExitCYY3CRVAction)

    # external things
    kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWalletAddress)

    bulk_actions = [
        # allow bots to call argobytes_trader.atomicArbitrage
        # TODO: allow bots to flash loan from WETH10 and DyDx and Uniswap and any other wrappers that we trust
        # TODO: think about this more
        (
            argobytes_authority,
            0,  # 0=CALL
            False,
            argobytes_authority.allow.encode_input(
                argobytes_proxy_arbitragers,
                argobytes_trader,
                0,  # 0=CALL
                argobytes_trader.atomicArbitrage.signature,
            ),
        ),
        # register for kyber's fee program
        (
            kyber_register_wallet,
            0,  # 0=CALL
            False,
            kyber_register_wallet.registerWallet.encode_input(argobytes_proxy_owner),
        ),
        # TODO: gas_token.buyAndFree or gas_token.free depending on off-chain balance/price checks
    ]

    argobytes_proxy_clone.executeMany(
        bulk_actions,
        {"gasPrice": expected_mainnet_gas_price}
    )

    print("gas used by accounts[0]:", accounts[0].gas_used)

    ending_balance = accounts[0].balance()

    assert ending_balance < starting_balance

    print("ETH used by accounts[0]:", (starting_balance - ending_balance) / 1e18)

    # save all the addresses we might use, not just ones for own contracts
    quick_save("CurveFiBUSD", CurveFiBUSDAddress)
    quick_save("CurveFiCompound", CurveFiCompoundAddress)
    quick_save("CurveFiPAX", CurveFiPAXAddress)
    quick_save("CurveFiREN", CurveFiRENAddress)
    quick_save("CurveFiSUSDV2", CurveFiSUSDV2Address)
    quick_save("CurveFiTBTC", CurveFiTBTCAddress)
    quick_save("CurveFiUSDT", CurveFiUSDTAddress)
    quick_save("CurveFiY", CurveFiYAddress)
    quick_save("KollateralInvoker", KollateralInvokerAddress)
    quick_save("KyberNetworkProxy", KyberNetworkProxyAddress)
    quick_save("KyberRegisterWallet", KyberRegisterWalletAddress)
    quick_save("OneSplit", OneSplitAddress)
    quick_save("SynthetixAddressResolver", SynthetixAddressResolverAddress)
    quick_save("UniswapFactory", UniswapV1FactoryAddress)
    quick_save("UniswapV2Router", UniswapV2RouterAddress)
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

    # TODO: gas golf createClone function that uses msg.sender instead of owner in the calldata?
    # TODO: free gas token
    deploy_tx = argobytes_factory.createClone(
        argobytes_proxy.address,
        salt,
        accounts[5],
        {
            "from": accounts[5],
            "gas_price": expected_mainnet_gas_price,
        },
    )

    argobytes_proxy_clone_5 = ArgobytesFlashBorrower.at(deploy_tx.return_value, accounts[5])

    bulk_actions = [
        # allow bots to call argobytes_trader.atomicArbitrage
        # TODO: think about this more. the msg.sendere might not be what we need
        (
            argobytes_authority,
            0,  # 0=Call
            False,
            argobytes_authority.allow.encode_input(
                argobytes_proxy_arbitragers,
                argobytes_trader,
                1,  # 1=delegatecall
                argobytes_trader.atomicArbitrage.signature,
            ),
        ),
        # TODO: gas_token.buyAndFree or gas_token.free depending on off-chain balance/price checks
    ]

    argobytes_proxy_clone_5.executeMany(
        bulk_actions,
        {"gasPrice": expected_mainnet_gas_price}
    )

    ending_balance = accounts[5].balance()

    print("ETH used by accounts[5] to deploy a proxy with auth:", (starting_balance - ending_balance) / 1e18)

    # make a clone for accounts[6]. then print total gas
    starting_balance = accounts[6].balance()

    # TODO: optionally free gas token
    deploy_tx = argobytes_factory.createClone(
        argobytes_proxy.address,
        salt,
        accounts[6],
        {
            "from": accounts[6],
            "gas_price": expected_mainnet_gas_price,
        },
    )

    argobytes_proxy_clone_6 = ArgobytesFlashBorrower.at(deploy_tx.return_value, accounts[6])

    ending_balance = accounts[6].balance()

    print("ETH used by accounts[6] to deploy a proxy:", (starting_balance - ending_balance) / 1e18)

    # reset_block_time(synthetix_depot_action)
