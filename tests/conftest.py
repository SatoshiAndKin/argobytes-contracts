import pytest
from brownie import accounts


# test isolation, always use!
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


@pytest.fixture(scope="module")
def atomic_trade(ArgobytesAtomicTrade, owned_vault):
    kollateral_invoker = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"

    atomic_trade_instance = accounts[0].deploy(
        ArgobytesAtomicTrade, kollateral_invoker, owned_vault)

    owned_vault.setArgobytesAtomicTrade(atomic_trade_instance)

    return atomic_trade_instance


@pytest.fixture(scope="module")
def example_action(ExampleAction):
    return accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="module")
def kyber_action(KyberAction):
    kyber_network_proxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
    kyber_wallet_id = "0x0000000000000000000000000000000000000000"
    return accounts[0].deploy(KyberAction, kyber_network_proxy, kyber_wallet_id)


@pytest.fixture(scope="module")
def onesplit_action(OneSplitAction):
    # TODO: does this support ENS? this is 1split.eth
    return accounts[0].deploy(OneSplitAction, "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E")


@pytest.fixture(scope="module")
def owned_vault(ArgobytesOwnedVault):
    gastoken = "0x0000000000b3F879cb30FE243b4Dfee438691c04"

    # deployer = accounts[0]
    arb_bots = [accounts[1]]

    return accounts[0].deploy(ArgobytesOwnedVault, gastoken, arb_bots)


# TODO: open a github issue so that we can access interfaces as fixtures
@pytest.fixture(scope="module")
def quick_and_dirty(QuickAndDirty):
    return accounts[0].deploy(QuickAndDirty)


@pytest.fixture(scope="module")
def uniswap_action(UniswapAction):
    uniswap_factory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"
    return accounts[0].deploy(UniswapAction, uniswap_factory)


@pytest.fixture(scope="module")
def weth9_action(Weth9Action, quick_and_dirty):
    weth9_erc20 = quick_and_dirty._weth9()

    return accounts[0].deploy(Weth9Action, weth9_erc20)
