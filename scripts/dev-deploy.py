# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`

from brownie import *
import os

CurveCompounded = "0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56"
CurveUSDT = "0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C"
CurveY = "0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51"
CurveB = "0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27"
CurveSUSDV2 = "0xA5407eAE9Ba41422680e2e00537571bcC53efBfD"
CurvePAX = "0x06364f10B501e868329afBc005b3492902d6C763"
# TODO: compare GST2 and 1inch's CHI
GasTokenAddress = "0x0000000000b3F879cb30FE243b4Dfee438691c04"
# GasTokenAddress = "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c"
KollateralInvokerAddress = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"
KyberRegisterWallet = "0xECa04bB23612857650D727B8ed008f80952654ee"
OneSplitAddress = "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E"
Weth9Address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
KyberNetworkProxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
# https://contracts.synthetix.io/ReadProxyAddressResolver
SynthetixAddressResolver = "0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2"
UniswapFactory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"
ZeroAddress = "0x0000000000000000000000000000000000000000"

# TODO: old versions of these contracts were cheaper to deploy with gas token. with less state, they are cheaper without gastoken though
# TODO: i think some of them might still be. investigate more
BURN_GAS_TOKEN = os.environ.get("BURN_GAS_TOKEN", "0") == "1"


def create_helper(deployer, target_contract, target_contract_args, gas_price):
    # TODO: docs for using ERADICATE 2 (will be easier since we already have argobytes_owned_vault's address)
    salt = ""

    initcode = target_contract.deploy.encode_input(*target_contract_args)

    if BURN_GAS_TOKEN:
        gastoken = GasTokenAddress
    else:
        gastoken = ZeroAddress

    deploy_tx = deployer.deploy2(gastoken, salt, initcode, {"from": accounts[0], "gasPrice": gas_price})

    deployed_address = deploy_tx.return_value

    deployed_contract = target_contract.at(deployed_address)

    print("CREATE2 deployed:", deployed_contract._name, "to", deployed_contract.address)
    print()

    return deployed_contract


def main():
    # gwei
    expected_mainntet_mint_price = 1 * 1e9
    expected_mainnet_gas_price = 15 * 1e9

    starting_balance = accounts[0].balance()

    arb_bots = [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    # TODO: docs for figuring out the address for ArgobytesOwnedVaultDeployer and then using ERADICATE2
    # TODO: maybe send gastoken to ArgobytesOwnedVaultDeployer before it is deployed. then burn all that token after selfdestruct?
    salt = ""

    argobytes_owned_vault_deployer_initcode = ArgobytesOwnedVaultDeployer.deploy.encode_input(
        salt, arb_bots)

    # we don't use the normal deploy function because the contract selfdestructs after deploying ArgobytesOwnedVault
    # https://github.com/iamdefinitelyahuman/brownie/issues/537
    # TODO: in production, we probably want to transfer
    argobytes_owned_vault_tx = accounts[0].transfer(
        data=argobytes_owned_vault_deployer_initcode, amount=0, gas_price=expected_mainnet_gas_price)

    # TODO: is this the best way to get an address out?
    argobytes_owned_vault = argobytes_owned_vault_tx.logs[0]['address']

    argobytes_owned_vault = ArgobytesOwnedVault.at(argobytes_owned_vault)

    print("ArgobytesOwnedVault address:", argobytes_owned_vault)

    # mint some gas token so we can have cheaper deploys for the rest of the contracts
    if BURN_GAS_TOKEN:
        for _ in range(0, 17):
            argobytes_owned_vault.mintGasToken(
                GasTokenAddress, 26, {"from": accounts[0], "gasPrice": expected_mainntet_mint_price})

        gas_token = interface.IGasToken(GasTokenAddress)

        gas_tokens_start = gas_token.balanceOf.call(argobytes_owned_vault)
        # gastoken has 2 decimals, so divide by 100
        print("Starting gas_token balance:", gas_tokens_start / 100.0)

    argobytes_atomic_trade = create_helper(argobytes_owned_vault, ArgobytesAtomicTrade, [], expected_mainnet_gas_price)

    # give the vault a bunch of coins
    accounts[1].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[2].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[3].transfer(argobytes_owned_vault, 50 * 1e18)

    # TODO: refactor all of these to use less storage and instead use calldata. its easier to upgrade without requiring admin keys this way. gas is also less for calldata compared to SLOAD
    create_helper(argobytes_owned_vault, OneSplitOffchainAction, [], expected_mainnet_gas_price)
    create_helper(argobytes_owned_vault, KyberAction, [accounts[0], argobytes_owned_vault], expected_mainnet_gas_price)
    create_helper(argobytes_owned_vault, UniswapV1Action, [], expected_mainnet_gas_price)
    create_helper(argobytes_owned_vault, Weth9Action, [], expected_mainnet_gas_price)
    create_helper(argobytes_owned_vault, SynthetixDepotAction, [], expected_mainnet_gas_price)

    curve_fi_action = create_helper(argobytes_owned_vault, CurveFiAction, [accounts[0]], expected_mainnet_gas_price)

    # TODO: do this through the vault so that we can burn gas token?
    curve_fi_action.saveExchange(CurveCompounded, 2, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveUSDT, 3, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveY, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveB, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurveSUSDV2, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})
    curve_fi_action.saveExchange(CurvePAX, 4, {"from": accounts[0], 'gasPrice': expected_mainnet_gas_price})

    # put some ETH on the atomic trade wrapper to fake an arbitrage opportunity
    # TODO: make a script to help with this
    accounts[1].transfer(argobytes_atomic_trade, 1e18)

    # register for kyber's fee program
    kyber_register_wallet = interface.KyberRegisterWallet(
        KyberRegisterWallet, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

    kyber_register_wallet.registerWallet(
        argobytes_owned_vault, {'from': accounts[0], 'gasPrice': expected_mainnet_gas_price})

    if BURN_GAS_TOKEN:
        # make sure we still have some gastoken left (this way we know how much we need before deploying on mainnet)
        gas_tokens_remaining = gas_token.balanceOf.call(argobytes_owned_vault)

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
