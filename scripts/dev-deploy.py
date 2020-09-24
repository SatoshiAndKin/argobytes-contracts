# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`

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


def quick_save_contract(contract):
    quick_save(contract._name, contract.address)


def quick_save(contract_name, address):
    """quick and dirty way to save contract addresses in an easy to read format."""
    if EXPORT_ARTIFACTS == False:
        print(f"{contract_name} is deployed at {address}\n")
        return

    quick_name = contract_name + ".addr"

    quick_path = os.path.join(DEPLOY_DIR, quick_name)

    print(f"Saving deployed address to {quick_path}")

    with open(quick_path, 'w') as opened_file:
        opened_file.write(address)


def main():
    os.makedirs(DEPLOY_DIR, exist_ok=True)

    # gas price should be 3.0x to 3.5x the mint price
    # TODO: double check and document why its 3.5x
    expected_mainnet_mint_price = "30 gwei"
    # unless you are in a rush, it is better to not use gas token and just deploy at expected_mainnet_mint_price
    expected_mainnet_gas_price = "100 gwei"

    deadline = 90000000000000000000

    arb_bots = [
        SKI_METAMASK_1,
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWalletAddress)

    # TODO: WARNING! SKI_METAMASK_1 is an admin role only for staging. this should be SKI_HARDWARE_1
    argobytes_diamond_admin = SKI_METAMASK_1

    argobytes_diamond_arbitragers = arb_bots + [SKI_METAMASK_1]

    starting_balance = accounts[0].balance()

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

    # deploy ArgobytesProxyFactory using LGT helper
    # TODO: calculate the optimal number of gas to buy
    # this contract is so small, that burning gas tokens is never economical
    # TODO: hmm. i'm getting revert: insufficient ether even when setting gas_token_amount to 0
    if FREE_GAS_TOKEN:
        free_num_gas_gas_tokens = 19
    else:
        free_num_gas_gas_tokens = 0

    deploy_tx = gas_token.create2(
        free_num_gas_gas_tokens,
        deadline,
        salt_uint,
        ArgobytesProxyFactory.deploy.encode_input(),
        {
            # this ether will get sent back if gas_token_amount is 0
            # TODO: calculate an actual amount for this
            "value": "1 ether",
        }
    )
    # TODO: check how much we spent on gas token

    argobytes_proxy_factory = ArgobytesProxyFactory.at(deploy_tx.return_value, accounts[0])
    quick_save_contract(argobytes_proxy_factory)

    if FREE_GAS_TOKEN:
        gas_token.approve(argobytes_proxy_factory, -1)

    # TODO: calculate gas_token_amount for an ArgobytesProxy
    deploy_tx = argobytes_proxy_factory.buildProxy(
        0,
        salt,
    )

    ds_proxy_address = deploy_tx.return_value

    # deploy a dsproxy just to compare gas costs
    ds_proxy_factory = interface.DSProxyFactory(DSProxyFactoryAddress, accounts[0])

    ds_proxy_tx = ds_proxy_factory.build()

    # TODO: setup auth for the proxy

    # deploy ArgobytesTrader
    # TODO: calculate gas_token_amount (make a helper function for this?)
    deploy_tx = argobytes_proxy_factory.deploy2(
        0,  # 14,
        salt,
        ArgobytesTrader.deploy.encode_input(),
        to_bytes(hexstr="0x"),
    )
    argobytes_trader = ArgobytesTrader.at(deploy_tx.return_value, accounts[0])
    quick_save_contract(argobytes_trader)

    assert False

    # deploy all the other contracts
    # these one's don't modify the diamond
    argobytes_atomic_actions = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        ArgobytesAtomicActions,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(argobytes_atomic_actions)

    example_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        ExampleAction,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(example_action)

    onesplit_offchain_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        OneSplitOffchainAction,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(onesplit_offchain_action)

    # TODO: think more about kyber's constructor. maybe wallet_id should be set/changeable by msg.sender
    kyber_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        KyberAction,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(kyber_action)

    uniswap_v1_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        UniswapV1Action,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(uniswap_v1_action)

    uniswap_v2_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        UniswapV2Action,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(uniswap_v2_action)

    # zrx_v3_action = deploy2_and_free(
    #     gas_token_for_freeing,
    #     argobytes_diamond,
    #     salt,
    #     ZrxV3Action,
    #     [],
    #     expected_mainnet_gas_price
    # )
    # quick_save_contract(zrx_v3_action)

    weth9_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        Weth9Action,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(weth9_action)

    synthetix_depot_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        SynthetixDepotAction,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(synthetix_depot_action)

    curve_fi_action = deploy2_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        CurveFiAction,
        [],
        expected_mainnet_gas_price
    )
    quick_save_contract(curve_fi_action)

    bulk_actions = [
        # add the curve fi contracts
        (
            curve_fi_action.address,
            curve_fi_action.saveExchange.encode_input(CurveFiBUSDAddress, 4),
            False,
        ),
        (
            curve_fi_action.address,
            curve_fi_action.saveExchange.encode_input(CurveFiCompoundAddress, 2),
            False,
        ),
        (
            curve_fi_action.address,
            curve_fi_action.saveExchange.encode_input(CurveFiSUSDV2Address, 4),
            False,
        ),
        (
            curve_fi_action.address,
            curve_fi_action.saveExchange.encode_input(CurveFiYAddress, 4),
            False,
        ),
        (
            curve_fi_action.address,
            curve_fi_action.saveExchange.encode_input(CurveFiBUSDAddress, 4),
            False,
        ),
        # TODO: bitcoin curve pools
        # TODO: add swerve pool
        # register for kyber's fee program
        (
            KyberRegisterWalletAddress,
            kyber_register_wallet.registerWallet.encode_input(argobytes_diamond),
            False,
        ),
    ]

    bulk_actions = argobytes_proxy.argobytesActions.encode_input(
        gas_token_for_freeing, argobytes_atomic_actions, bulk_actions)

    argobytes_diamond.diamondCutAndFree(
        gas_token,
        [argobytes_owned_vault_cuts],
        "0x0000000000000000000000000000000000000000",
        bulk_actions,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price}
    )

    # TODO: setup roles in one transaction (we can't do it inside bulk_actions because msg.sender is no longer the admin)

    # grant admin roles
    argobytes_diamond.grantRole(
        argobytes_owned_vault.DEFAULT_ADMIN_ROLE(),
        argobytes_diamond_admin,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price},
    )

    # grant trusted arbitrager roles
    # TODO: does this actually save us gas?
    argobytes_diamond.grantRoles(
        argobytes_owned_vault.TRUSTED_ARBITRAGER_ROLE(),
        argobytes_diamond_arbitragers,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price},
    )

    # grant exit roles
    argobytes_diamond.grantRole(
        argobytes_owned_vault.EXIT_ROLE(),
        argobytes_diamond_exit,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price},
    )

    # grant alarm roles
    argobytes_diamond.grantRole(
        argobytes_owned_vault.ALARM_ROLE(),
        argobytes_diamond_alarm,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price},
    )

    if FREE_GAS_TOKEN:
        # # TODO: make sure we still have some gastoken left (this way we know how much we need before deploying on mainnet)
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_diamond)

        print("gas token:", LiquidGasTokenAddress)

        print("gas_tokens_remaining:", gas_tokens_remaining, "/", gas_tokens_start)

        assert gas_tokens_remaining > 0
        assert gas_tokens_remaining <= mint_batch_amount
    elif MINT_GAS_TOKEN:
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_diamond)

        print("gas token:", LiquidGasTokenAddress)

        print("gas_tokens_remaining:", gas_tokens_remaining)

        assert gas_tokens_remaining > 0
    else:
        print("gas_tokens_remaining: N/A")

    print("gas used by accounts[0]:", accounts[0].gas_used)

    ending_balance = accounts[0].balance() + diamond.balance()

    assert ending_balance < starting_balance

    # this isn't all used by gas. some is sent to the owned vault
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
    quick_save("Weth9", Weth9Address)
    quick_save("YearnEthVault", YearnEthVaultAddress)

    # give the argobytes_diamond a bunch of coins. it will forward them when deploying the diamond
    accounts[1].transfer(argobytes_diamond, 50 * 1e18)
    accounts[2].transfer(argobytes_diamond, 50 * 1e18)
    accounts[3].transfer(argobytes_diamond, 50 * 1e18)
    accounts[4].transfer(argobytes_diamond_admin, 30 * 1e18)
    accounts[4].transfer(argobytes_diamond_arbitragers[0], 30 * 1e18)

    reset_block_time(synthetix_depot_action)
