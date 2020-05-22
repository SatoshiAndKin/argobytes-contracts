from brownie import *

CurveCompounded = "0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56"
CurveUSDT = "0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C"
CurveY = "0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51"
CurveB = "0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27"
CurveSUSDV2 = "0xA5407eAE9Ba41422680e2e00537571bcC53efBfD"
CurvePAX = "0x06364f10B501e868329afBc005b3492902d6C763"
GasTokenAddress = "0x0000000000b3F879cb30FE243b4Dfee438691c04"
KollateralInvokerAddress = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"
KyberRegisterWallet = "0xECa04bB23612857650D727B8ed008f80952654ee"
OneSplitAddress = "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E"
Weth9Address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
KyberNetworkProxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
# https://contracts.synthetix.io/ReadProxyAddressResolver
SynthetixAddressResolver = "0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2"
UniswapFactory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"


def main():
    arb_bots = [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    # TODO: docs for using ERADICATE2
    salt = ""

    # TODO: refactor for gastoken incoming
    argobytes_owned_vault_deployer_initcode = ArgobytesOwnedVaultDeployer.deploy.encode_input(
        salt, GasTokenAddress, arb_bots)

    # we don't use the normal deploy function because the contract selfdestructs after deploying ArgobytesOwnedVault
    argobytes_owned_vault_tx = accounts[0].transfer(data=argobytes_owned_vault_deployer_initcode, amount=50 * 1e18)

    # TODO: is this the best way to get an address out? i feel like it should already be in logs
    # argobytes_owned_vault = argobytes_owned_vault_tx.events["Deployed"]["argobytes_owned_vault"]
    argobytes_owned_vault = argobytes_owned_vault_tx.logs[0]['address']

    argobytes_owned_vault = ArgobytesOwnedVault.at(argobytes_owned_vault)

    print("ArgobytesOwnedVault address:", argobytes_owned_vault)

    # mint some gas token so we can have cheaper deploys for the rest of the contracts
    argobytes_owned_vault.mintGasToken({"from": accounts[0]})

    argobytes_atomic_trade_initcode = ArgobytesAtomicTrade.deploy.encode_input()

    # TODO: docs for using ERADICATE 2 (will be easier since we already have argobytes_owned_vault's address)
    argobytes_atomic_trade = argobytes_owned_vault.deploy2(salt, argobytes_atomic_trade_initcode, {"from": accounts[0]})

    argobytes_atomic_trade = ArgobytesAtomicTrade.at(argobytes_atomic_trade.return_value)

    print("ArgobytesAtomicTrade address:", argobytes_atomic_trade)

    # TODO: our rust code doesn't check our real balances yet, so just give the vault a bunch of coins
    accounts[1].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[2].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[3].transfer(argobytes_owned_vault, 50 * 1e18)

    OneSplitOffchainAction.deploy(OneSplitAddress, {'from': accounts[0]})
    KyberAction.deploy(KyberNetworkProxy, argobytes_owned_vault, {'from': accounts[0]})
    UniswapAction.deploy(UniswapFactory, {'from': accounts[0]})
    Weth9Action.deploy(Weth9Address, {'from': accounts[0]})
    SynthetixDepotAction.deploy(SynthetixAddressResolver, {'from': accounts[0]})
    CurveFiAction.deploy(CurveCompounded, 2, {'from': accounts[0]})
    CurveFiAction.deploy(CurveUSDT, 3, {'from': accounts[0]})
    CurveFiAction.deploy(CurveY, 4, {'from': accounts[0]})
    CurveFiAction.deploy(CurveB, 4, {'from': accounts[0]})
    CurveFiAction.deploy(CurveSUSDV2, 4, {'from': accounts[0]})
    CurveFiAction.deploy(CurvePAX, 4, {'from': accounts[0]})

    # # put some ETH on the atomic trade wrapper to fake an arbitrage opportunity even if it actually loses money
    accounts[1].transfer(argobytes_atomic_trade, 1e18)

    kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWallet, {'from': accounts[0]})

    kyber_register_wallet.registerWallet(argobytes_owned_vault, {'from': accounts[0]})

    # TODO: make sure we still have some gastoken left (this way we know how much we need before deploying on mainnet)
