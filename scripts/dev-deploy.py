# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`

from brownie import *
from eth_abi.packed import encode_abi_packed
import os
import binascii

CurveFiBUSD = "0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27"
CurveFiCompound = "0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56"
CurveFiPAX = "0x06364f10B501e868329afBc005b3492902d6C763"
CurveFiREN = "0x93054188d876f558f4a66B2EF1d97d16eDf0895B"
CurveFiSUSDV2 = "0xA5407eAE9Ba41422680e2e00537571bcC53efBfD"
CurveFiTBTC = "0x9726e9314eF1b96E45f40056bEd61A088897313E"
CurveFiUSDT = "0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C"
CurveFiY = "0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51"
GasToken2 = "0x0000000000b3F879cb30FE243b4Dfee438691c04"
CHI = "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c"  # 1inch's CHI
KollateralInvokerAddress = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"
KyberRegisterWallet = "0xECa04bB23612857650D727B8ed008f80952654ee"
OneSplitAddress = "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E"
Weth9Address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
KyberNetworkProxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
# https://contracts.synthetix.io/ReadProxyAddressResolver
SynthetixAddressResolver = "0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2"
UniswapFactory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"
ZeroAddress = "0x0000000000000000000000000000000000000000"
# ZrxFowarderAddress = "0x0000000000000000000000000000000000000000"

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
        cut = binascii.unhexlify(deployed_contract.signatures[deployed_sig][2:])

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


def create_helper_with_gastoken(deployer, target_contract, target_contract_args, gas_price):
    # TODO: docs for using ERADICATE 2 (will be easier since we already have argobytes_owned_vault's address)
    salt = ""

    initcode = target_contract.deploy.encode_input(*target_contract_args)

    if BURN_GAS_TOKEN:
        gastoken = GasTokenAddress
    else:
        gastoken = ZeroAddress

    deploy_tx = deployer.deploy2_and_burn(gastoken, salt, initcode, {"from": accounts[0], "gasPrice": gas_price})

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

    deployed_contract = target_contract.at(deployed_address)

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


def reset_block_time(synthetix_depot_action):
    # synthetix_address_resolver = interface.IAddressResolver(SynthetixAddressResolver)

    # TODO: get this from the address resolver instead
    synthetix_exchange_rates = Contract.from_explorer("0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77")

    token_bytestr = synthetix_depot_action.BYTESTR_ETH()

    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time: ", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    web3.testing.mine(last_update_time)


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

    # prepare a diamond. we will add ArgobytesOwnedVault functions to this
    diamond_initcode = Diamond.deploy.encode_input(salt, salt)

    # deploy the contract that will deploy the diamond
    # it self destructs, so handling it is non-standard
    diamond_deploy_tx = DiamondCreator.deploy(
        GasTokenAddress,
        salt,
        diamond_initcode,
        {"from": accounts[0], "gasPrice": expected_mainnet_gas_price}
    )

    # deploys have no return_value, so we check logs instead
    diamond_address = diamond_deploy_tx.logs[0]['address']

    diamond = Diamond.at(diamond_address)

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
