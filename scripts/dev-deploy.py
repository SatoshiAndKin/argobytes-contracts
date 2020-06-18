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


def create_helper(deployer, target_contract, target_contract_args, gas_price):
    # TODO: docs for using ERADICATE 2 (will be easier since we already have argobytes_owned_vault's address)
    salt = ""

    initcode = target_contract.deploy.encode_input(*target_contract_args)

    deploy_tx = deployer.deploy2(salt, initcode, {"from": accounts[0], "gasPrice": gas_price})

    if hasattr(deploy_tx, "return_value"):
        # this should be the normal path
        deployed_address = deploy_tx.return_value
    else:
        # i think this is a bug
        # no return_value, so we check logs instead
        # TODO: i don't think this log should be needed
        events = deploy_tx.events[-1]

        deployed_address = events['deployed']

    deployed_contract = target_contract.at(deployed_address)

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

    deployed_address = deploy_tx.return_value

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
        print(f"Deployed {contract_name} to {address}")
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

    # deploy a diamond. we will add ArgobytesOwnedVault functions to this
    # TODO: mint and send gas token to the expected diamond deployer address. it should forward them to the deployed contract
    # TODO: do some cuts here?
    diamond_deploy_tx = DiamondDeployer.deploy(salt, salt, salt, [], {"from": accounts[0]})

    # there is a tx.new_contracts, but because of how we self-destruct the DiamondDeployer, it isn't populated
    diamond = Diamond.at(diamond_deploy_tx.logs[0]['address'])

    # save the diamond's address
    quick_save_contract(diamond)

    # this interface matches our final cut diamond (IDiamondCutter+IDiamondLoupe+IArgobytesOwnedVault)
    argobytes_diamond = interface.IArgobytesDiamond(diamond.address)

    # deploy ArgobytesOwnedVault. we won't use this directly. it will be used through the diamond
    # TODO: use gas token here
    argobytes_owned_vault = create_helper(argobytes_diamond, ArgobytesOwnedVault, [], expected_mainnet_gas_price)

    cuts = [
        # abi.encodePacked(address, selector1, ..., selectorN)
        encode_abi_packed(
            ['address'] + ['bytes4'] * 7,
            (
                argobytes_owned_vault.address,
                binascii.unhexlify(ArgobytesOwnedVault.signatures["trustArbitragers"][2:]),
                binascii.unhexlify(ArgobytesOwnedVault.signatures["atomicArbitrage"][2:]),
                binascii.unhexlify(ArgobytesOwnedVault.signatures["deploy2_and_burn"][2:]),
                binascii.unhexlify(ArgobytesOwnedVault.signatures["deploy2_cut_and_burn"][2:]),
                binascii.unhexlify(ArgobytesOwnedVault.signatures["withdrawTo"][2:]),
                binascii.unhexlify(ArgobytesOwnedVault.signatures["withdrawToFreeGas"][2:]),
                binascii.unhexlify(ArgobytesOwnedVault.signatures["mintGasToken"][2:]),
            )
        )
    ]

    argobytes_diamond.diamondCut(cuts, {"from": accounts[0]})

    # now that we've added our functions we can use the ArgobytesOwnedVault on the diamond
    argobytes_diamond.trustArbitragers(arb_bots, {"from": accounts[0]})

    # mint some gas token so we can have cheaper deploys for the rest of the contracts
    if BURN_GAS_TOKEN:
        for _ in range(0, 18):
            argobytes_diamond.mintGasToken(
                GasTokenAddress, 26, {"from": accounts[0], "gasPrice": expected_mainnet_mint_price})

        gas_token = interface.IGasToken(GasTokenAddress)

        gas_tokens_start = gas_token.balanceOf.call(argobytes_diamond)
        # gastoken has 2 decimals, so divide by 100
        print("Starting gas_token balance:", gas_tokens_start / 100.0)

    argobytes_atomic_trade = create_helper_with_gastoken(
        argobytes_diamond, ArgobytesAtomicTrade, [], expected_mainnet_gas_price)

    # give the vault a bunch of coins
    accounts[1].transfer(argobytes_diamond, 50 * 1e18)
    accounts[2].transfer(argobytes_diamond, 50 * 1e18)
    accounts[3].transfer(argobytes_diamond, 50 * 1e18)

    create_helper_with_gastoken(argobytes_diamond, OneSplitOffchainAction, [], expected_mainnet_gas_price)
    create_helper_with_gastoken(argobytes_diamond, KyberAction, [
                                accounts[0], argobytes_diamond], expected_mainnet_gas_price)
    create_helper_with_gastoken(argobytes_diamond, UniswapV1Action, [], expected_mainnet_gas_price)
    # create_helper(argobytes_diamond, ZrxV3Action, [], expected_mainnet_gas_price)
    create_helper_with_gastoken(argobytes_diamond, Weth9Action, [], expected_mainnet_gas_price)
    synthetix_depot_action = create_helper_with_gastoken(
        argobytes_diamond, SynthetixDepotAction, [], expected_mainnet_gas_price)

    curve_fi_action = create_helper_with_gastoken(argobytes_diamond, CurveFiAction, [
        accounts[0]], expected_mainnet_gas_price)

    # TODO: do this through the vault so that we can burn gas token?
    curve_fi_action.saveExchange(CurveFiBUSD, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiCompound, 2, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiPAX, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    # curve_fi_action.saveExchange(CurveFiREN, 2, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiSUSDV2, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    # curve_fi_action.saveExchange(CurveFiTBTC, 3, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiUSDT, 3, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveFiY, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})

    # put some ETH on the atomic trade wrapper to fake an arbitrage opportunity
    # TODO: make a script to help with this
    accounts[1].transfer(argobytes_atomic_trade, 1e18)

    # register for kyber's fee program
    kyber_register_wallet = interface.KyberRegisterWallet(
        KyberRegisterWallet, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

    kyber_register_wallet.registerWallet(
        argobytes_diamond, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

    if BURN_GAS_TOKEN:
        # make sure we still have some gastoken left (this way we know how much we need before deploying on mainnet)
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_owned_vault)

        print("gas token:", GasTokenAddress)

        # gastoken has 2 decimals, so divide by 100
        print("gas_tokens_remaining:", gas_tokens_remaining / 100.0, "/", gas_tokens_start / 100.0)

        assert gas_tokens_remaining > 0
        # TODO: get the amount minted from the contract
        assert gas_tokens_remaining < 26
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
