# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`

from argobytes_util import *
from argobytes_mainnet import *
from brownie import *
from eth_abi import encode_single, encode_abi
from eth_utils import to_bytes
import os


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
        return

    quick_name = contract_name + ".addr"

    quick_path = os.path.join(DEPLOY_DIR, quick_name)

    print(f"Saving deployed address to {quick_path}")

    with open(quick_path, 'w') as opened_file:
        opened_file.write(address)


def main():
    os.makedirs(DEPLOY_DIR, exist_ok=True)

    # gwei
    # gas price should be 3.0x to 3.5x the mint price
    # TODO: double check and document why its 3.5x
    # unless you are in a rush, it is better to just deploy at low gas prices
    expected_mainnet_mint_price = "20 gwei"
    expected_mainnet_gas_price = "60 gwei"

    starting_balance = accounts[0].balance()

    arb_bots = [
        SKI_METAMASK_1,
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    # TODO: docs for figuring out the address for DiamondDeployer and then using ERADICATE2
    salt = ""

    gas_token = interface.ILiquidGasToken(LiquidGasTokenAddress)

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
        num_mints = 15

        expected_diamond_creator_address = mk_contract_address(accounts[0].address, accounts[0].nonce + num_mints)

        print("Minting gas_token for", expected_diamond_creator_address)

        # add some LGT liquidity
        # TODO: how many tokens should we mint? what size liquidity pool and at what price do we expect to see?
        # TODO: what should we set the price of LGT to?
        mint_batch_amount = 50
        for _ in range(0, num_mints):
            # TODO: im still not positive we want mintToLiqudity instead of mintTo
            # TODO: keep track of gas spent minting liquidity
            # gas_token.mintToLiquidity(mint_batch_amount, 0, deadline, accounts[1], {
            #                           'from': accounts[1], 'value': 1e19, "gasPrice": expected_mainnet_mint_price})
            gas_token.mintFor(mint_batch_amount, expected_diamond_creator_address, {
                'from': accounts[0], "gasPrice": expected_mainnet_mint_price})

        gas_tokens_start = gas_token.balanceOf.call(expected_diamond_creator_address)

        # gastoken has 2 decimals, so divide by 100
        print("Starting gas_token balance:", gas_tokens_start)

        # TODO: proper assert. mint_batch_amount is not the right amount to check
        assert gas_tokens_start == mint_batch_amount * num_mints
    else:
        expected_diamond_creator_address = mk_contract_address(accounts[0].address, accounts[0].nonce)

    # save the diamond creator's address
    # even though this contract self-destructs, we want to know the address so that we can pre-fund it with gastokens
    quick_save("DiamondCreator", expected_diamond_creator_address)

    # deploy the contract that will deploy the diamond (and cutter and loupe)
    # it self destructs, so handling it is non-standard
    # TODO: use the LGT deploy2 helper for the initial deployment
    diamond_creator_tx = DiamondCreator.deploy(
        accounts[0],
        salt,
        salt,
        salt,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price, "value": 1e18}
    )

    # deploys have no return_value, so we check logs instead
    # TODO: double check that this is the right log
    diamond_address = diamond_creator_tx.logs[0]['address']

    diamond = Diamond.at(diamond_address)

    print("DiamondCreator deployed Diamond to", diamond_address)
    print()

    # save the diamond's address
    quick_save("ArgobytesDiamond", diamond.address)

    # TODO: if we are burning gas token, check the balance here to make sure it transfered

    # this interface matches our final cut diamond:
    # IDiamondCutter+IDiamondLoupe+IArgobytesOwnedVault+ILiquidGasTokenUser+IERC165
    # not all those functions are actually available yet!
    argobytes_diamond = interface.IArgobytesDiamond(diamond.address)

    # deploy ArgobytesOwnedVault and add it to the diamond
    argobytes_owned_vault = deploy2_and_cut_and_free(
        gas_token_for_freeing,
        argobytes_diamond,
        salt,
        ArgobytesOwnedVault,
        [],
        [
            "adminAtomicActions",
            "adminAtomicTrades",
            "adminCall",
            "adminDelegateCall",
            "atomicArbitrage",
            "grantRoles",
            "emergencyExit",
        ],
        expected_mainnet_gas_price
    )
    quick_save_contract(argobytes_owned_vault)

    # TODO: do this in one transaction (maybe even inside the deploy2 and cut and free)
    # TODO: maybe have a "grantMultipleRoles" function

    # TODO: WARNING! SKI_METAMASK_1 is an admin role only for staging. this should be SKI_HARDWARE_1
    argobytes_diamond_admins = [SKI_METAMASK_1]

    # TODO: have a multi-signature cold storage or something similarly secure for this
    argobytes_diamond_exit = SKI_HARDWARE_1

    argobytes_diamond.grantRoles(
        argobytes_owned_vault.DEFAULT_ADMIN_ROLE(),
        argobytes_diamond_admins,
        {
            "from": accounts[0], "gasPrice": expected_mainnet_gas_price
        }
    )

    argobytes_diamond.grantRole(
        argobytes_owned_vault.EXIT_ROLE(),
        argobytes_diamond_exit,
        {
            "from": accounts[0], "gasPrice": expected_mainnet_gas_price
        }
    )

    argobytes_diamond_arbitragers = arb_bots + [SKI_METAMASK_1]

    argobytes_diamond.grantRoles(
        argobytes_owned_vault.TRUSTED_ARBITRAGER_ROLE(),
        argobytes_diamond_arbitragers,
        {
            "from": accounts[0], "gasPrice": expected_mainnet_gas_price
        }
    )

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
        [argobytes_diamond],
        expected_mainnet_gas_price
    )
    quick_save_contract(curve_fi_action)

    kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWalletAddress)

    actions = [
        # # add all the curve fi contracts
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
        # register for kyber's fee program
        (
            KyberRegisterWalletAddress,
            kyber_register_wallet.registerWallet.encode_input(argobytes_diamond),
            False,
        )
    ]

    argobytes_diamond.adminAtomicActions(
        gas_token_for_freeing, argobytes_atomic_actions, actions, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

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

    # give the argobytes_diamond a bunch of coins. it will forward them when deploying the diamond
    accounts[1].transfer(argobytes_diamond, 50 * 1e18)
    accounts[2].transfer(argobytes_diamond, 50 * 1e18)
    accounts[3].transfer(argobytes_diamond, 50 * 1e18)

    reset_block_time(synthetix_depot_action)
