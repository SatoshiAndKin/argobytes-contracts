# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`

from argobytes_util import *
from argobytes_mainnet import *
from brownie import *
from eth_abi.packed import encode_abi_packed
from eth_utils import to_bytes
import os


# TODO: set these inside main instead of using globals
# GasToken, GasToken2, CHI, or probably other future coins
GasTokenAddress = CHI

# TODO: old versions of these contracts were cheaper to deploy with gas token. with less state, they are cheaper without gastoken though
# TODO: i think some of them might still be. investigate more
BURN_GAS_TOKEN = os.environ.get("BURN_GAS_TOKEN", "0") == "1"
EXPORT_ARTIFACTS = os.environ.get("EXPORT_ARTIFACTS", "0") == "1"
DEPLOY_DIR = os.path.join(project.main.check_for_project('.'), "build", "deployments", "quick_and_dirty")

os.makedirs(DEPLOY_DIR, exist_ok=True)


def deploy2_and_burn(deployer, deployed_salt, deployed_contract, deployed_contract_args, gas_price):
    deployed_initcode = deployed_contract.deploy.encode_input(*deployed_contract_args)

    # TODO: print the expected address for this target_salt and deployed_initcode

    deploy_tx = deployer.deploy2AndBurn(
        GasTokenAddress,
        deployed_salt,
        deployed_initcode,
        {"from": accounts[0], "gasPrice": gas_price}
    )

    if hasattr(deploy_tx, "return_value"):
        # this should be the normal path
        deployed_address = deploy_tx.return_value
    else:
        # print(deploy_tx.events)

        # i think this is a bug
        # no return_value, so we check logs instead
        # TODO: i don't think this log should be needed
        events = deploy_tx.events['Deploy'][0]

        deployed_address = events['deployed']

    deployed_contract = deployed_contract.at(deployed_address)

    print("CREATE2 deployed:", deployed_contract._name, "to", deployed_contract.address)
    print()

    quick_save_contract(deployed_contract)

    return deployed_contract


def deploy2_and_cut_and_burn(deployer, deployed_salt, deployed_contract, deployed_contract_args, deployed_sigs, gas_price):
    deployed_initcode = deployed_contract.deploy.encode_input(*deployed_contract_args)

    encoded_sigs = []
    for deployed_sig in deployed_sigs:
        # TODO: whats the maximum number of selectors?
        cut = to_bytes(hexstr=deployed_contract.signatures[deployed_sig])

        encoded_sigs.append(cut)

    encoded_sigs = tuple(encoded_sigs)

    # TODO: whats the maximum number of selectors?
    # abi.encodePacked(address, selector1, ..., selectorN)
    encoded_sigs = encode_abi_packed(
        ['bytes4'] * len(encoded_sigs),
        tuple(encoded_sigs)
    )

    # TODO: print the expected address for this target_salt and initcode

    deploy_tx = deployer.deploy2AndCutAndBurn(
        GasTokenAddress,
        deployed_salt,
        deployed_initcode,
        encoded_sigs,
        {"from": accounts[0], "gasPrice": gas_price}
    )

    if hasattr(deploy_tx, "return_value"):
        # this should be the normal path
        deployed_address = deploy_tx.return_value
    else:
        # print(deploy_tx.events)

        # i think this is a bug
        # no return_value, so we check logs instead
        # TODO: i don't think this log should be needed
        events = deploy_tx.events['Deploy'][0]

        deployed_address = events['deployed']

    deployed_contract = deployed_contract.at(deployed_address)

    print("CREATE2 deployed:", deployed_contract._name, "to", deployed_contract.address)
    print()

    quick_save_contract(deployed_contract)

    return deployed_contract


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
    # gwei
    expected_mainnet_mint_price = 1 * 1e9
    expected_mainnet_gas_price = 25 * 1e9

    starting_balance = accounts[0].balance()

    arb_bots = [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    # TODO: docs for figuring out the address for DiamondDeployer and then using ERADICATE2
    # TODO: maybe send gastoken to DiamondDeployer before it is deployed. then burn/transfer that token after selfdestruct?
    salt = ""

    # TODO: do this earlier and transfer the coins to the diamond_creator address before deployment
    # mint some gas token so we can have cheaper deploys for the rest of the contracts
    if BURN_GAS_TOKEN:
        mint_batch_amount = 50

        gas_token = interface.IGasToken(GasTokenAddress)

        # TODO: only mint 1 more token than we need (instead of up to mint_batch_amount - 1 more)
        for _ in range(1, 14):
            # TODO: move this back to account 0 once we we calculate diamond_creator_address
            gas_token.mint(
                mint_batch_amount,
                {"from": accounts[0], "gasPrice": expected_mainnet_mint_price}
            )

        gas_tokens_start = gas_token.balanceOf.call(accounts[0])

        # prepare the diamond creator with some gas token
        # TODO: how do we calculate this contract's address before we do the deployment?
        # TODO: we need the current nonces for accounts[0] and some hashing
        print("WARNING! calculate instead of hard code this!")
        diamond_creator_address = "0xAF75C9E8b9c4C96053bCD5a5eBA3bC7d79dE2bC5"

        gas_token.transfer(
            diamond_creator_address,
            gas_tokens_start,
            {"from": accounts[0], "gasPrice": expected_mainnet_mint_price}
        )

        gas_tokens_start = gas_token.balanceOf.call(diamond_creator_address)

        # gastoken has 2 decimals, so divide by 100
        print("Starting gas_token balance:", gas_tokens_start / 100.0)

        # TODO: proper assert
        assert gas_tokens_start > mint_batch_amount

    # deploy the contract that will deploy the diamond (and cutter and loupe)
    # it self destructs, so handling it is non-standard
    diamond_deploy_tx = DiamondCreator.deploy(
        GasTokenAddress,
        salt,
        salt,
        salt,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price}
    )

    # deploys have no return_value, so we check logs instead
    diamond_address = diamond_deploy_tx.logs[0]['address']

    diamond = Diamond.at(diamond_address)

    print("Self-destructing DiamondCreator deployed Diamond to", diamond_address)
    print()

    # save the diamond's address
    quick_save_contract(diamond)

    # this interface matches our final cut diamond:
    # IDiamondCutter+IDiamondLoupe+IArgobytesOwnedVault+IGasTokenBurner+IERC165
    # not all those functions are actually available yet!
    argobytes_diamond = interface.IArgobytesDiamond(diamond.address)

    # give the diamond_creator a bunch of coins. it will forward them when deploying the diamond
    accounts[1].transfer(argobytes_diamond, 50 * 1e18)
    accounts[2].transfer(argobytes_diamond, 50 * 1e18)
    accounts[3].transfer(argobytes_diamond, 50 * 1e18)

    # deploy ArgobytesOwnedVault. we won't use this directly. it will be used through the diamond
    deploy2_and_cut_and_burn(
        argobytes_diamond,
        salt,
        ArgobytesOwnedVault,
        [],
        ["atomicArbitrage", "mintGasToken", "trustArbitragers", "withdrawTo", "withdrawToFreeGas"],
        expected_mainnet_gas_price
    )

    # use our fresh functions
    argobytes_diamond.trustArbitragers(
        GasTokenAddress,
        arb_bots,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price}
    )

    # deploy all the other contracts
    # these one's don't modify the diamond
    argobytes_atomic_trade = deploy2_and_burn(
        argobytes_diamond,
        salt,
        ArgobytesAtomicTrade,
        [],
        expected_mainnet_gas_price
    )

    deploy2_and_burn(
        argobytes_diamond,
        salt,
        OneSplitOffchainAction,
        [],
        expected_mainnet_gas_price
    )

    deploy2_and_burn(
        argobytes_diamond,
        salt,
        KyberAction,
        [accounts[0], argobytes_diamond],
        expected_mainnet_gas_price
    )

    deploy2_and_burn(
        argobytes_diamond,
        salt,
        UniswapV1Action,
        [],
        expected_mainnet_gas_price
    )

    # deploy2_and_burn(
    #     argobytes_diamond,
    #     salt,
    #     ZrxV3Action,
    #     [],
    #     expected_mainnet_gas_price
    # )

    deploy2_and_burn(
        argobytes_diamond,
        salt,
        Weth9Action,
        [],
        expected_mainnet_gas_price
    )

    synthetix_depot_action = deploy2_and_burn(
        argobytes_diamond,
        salt,
        SynthetixDepotAction,
        [],
        expected_mainnet_gas_price
    )

    curve_fi_action = deploy2_and_burn(
        argobytes_diamond,
        salt,
        CurveFiAction,
        [accounts[0]],
        expected_mainnet_gas_price
    )

    # TODO: do this through the vault so that we can burn gas token?
    curve_fi_action.saveExchange(CurveFiBUSD, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiCompound, 2, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiPAX, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    # curve_fi_action.saveExchange(CurveFiREN, 2, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiSUSDV2, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    # curve_fi_action.saveExchange(CurveFiTBTC, 3, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiUSDT, 3, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiY, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})

    # register for kyber's fee program
    kyber_register_wallet = interface.KyberRegisterWallet(
        KyberRegisterWallet, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

    kyber_register_wallet.registerWallet(
        argobytes_diamond, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

    if BURN_GAS_TOKEN:
        # make sure we still have some gastoken left (this way we know how much we need before deploying on mainnet)
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_diamond)

        print("gas token:", GasTokenAddress)

        # gastoken has 2 decimals, so divide by 100
        print("gas_tokens_remaining:", gas_tokens_remaining / 100.0, "/", gas_tokens_start / 100.0)

        assert gas_tokens_remaining > 0
        assert gas_tokens_remaining < mint_batch_amount
    else:
        print("gas_tokens_remaining: N/A")

    print("gas used by accounts[0]:", accounts[0].gas_used)

    ending_balance = accounts[0].balance()

    # this isn't all used by gas. some is sent to the owned vault
    print("ETH used by accounts[0]:", (starting_balance - ending_balance) / 1e18)

    # save all the addresses we might use, not just ones for own contracts
    quick_save("CHI", CHI)
    quick_save("CurveFiBUSD", CurveFiBUSD)
    quick_save("CurveFiCompound", CurveFiCompound)
    quick_save("CurveFiPAX", CurveFiPAX)
    quick_save("CurveFiREN", CurveFiREN)
    quick_save("CurveFiSUSDV2", CurveFiSUSDV2)
    quick_save("CurveFiTBTC", CurveFiTBTC)
    quick_save("CurveFiUSDT", CurveFiUSDT)
    quick_save("CurveFiY", CurveFiY)
    quick_save("GasToken2", GasToken2)
    quick_save("KollateralInvoker", KollateralInvokerAddress)
    quick_save("KyberNetworkProxy", KyberNetworkProxy)
    quick_save("KyberRegisterWallet", KyberRegisterWallet)
    quick_save("OneSplit", OneSplitAddress)
    quick_save("SynthetixAddressResolver", SynthetixAddressResolver)
    quick_save("UniswapFactory", UniswapFactory)
    quick_save("Weth9", Weth9Address)

    reset_block_time(synthetix_depot_action)
