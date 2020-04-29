from brownie import *

GasTokenAddress = "0x0000000000b3F879cb30FE243b4Dfee438691c04"
KollateralInvokerAddress = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"
OneSplitAddress = "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E"
Weth9Address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

KyberNetworkProxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
KyberWalletId = "0x0000000000000000000000000000000000000000"
UniswapFactory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"


def main():
    arb_bots = [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    argobytes_owned_vault = ArgobytesOwnedVault.deploy(GasTokenAddress, arb_bots, {'from': accounts[0]})

    argobytes_atomic_trade = ArgobytesAtomicTrade.deploy(
        KollateralInvokerAddress, argobytes_owned_vault, {'from': accounts[0]})

    argobytes_owned_vault.setArgobytesAtomicTrade(argobytes_atomic_trade)

    # TODO: our rust code doesn't check our real balances yet, so just give the vault a ton of coins
    accounts[0].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[1].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[2].transfer(argobytes_owned_vault, 50 * 1e18)
    accounts[3].transfer(argobytes_owned_vault, 50 * 1e18)

    OneSplitOffchainAction.deploy(OneSplitAddress, {'from': accounts[0]})
    KyberAction.deploy(KyberNetworkProxy, KyberWalletId, {'from': accounts[0]})
    UniswapAction.deploy(UniswapFactory, {'from': accounts[0]})
    weth9_action = Weth9Action.deploy(Weth9Address, {'from': accounts[0]})

    # put some ETH on the atomic trade wrapper to fake an arbitrage opportunity even if it actually loses money
    accounts[1].transfer(argobytes_atomic_trade, 1e18)
