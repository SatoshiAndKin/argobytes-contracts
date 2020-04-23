import pytest
from brownie import accounts, Contract


# test isolation, always use!
# be careful though! you can still leak state in other fixtures use scope="module" or scope="session"
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


@pytest.fixture()
def atomic_trade(ArgobytesAtomicTrade, owned_vault):
    kollateral_invoker = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"

    atomic_trade_instance = accounts[0].deploy(ArgobytesAtomicTrade, kollateral_invoker, owned_vault)

    owned_vault.setArgobytesAtomicTrade(atomic_trade_instance)

    return atomic_trade_instance


@pytest.fixture(scope="session")
def dai_erc20():
    return Contract.from_explorer("0x6b175474e89094c44da98b954eedeac495271d0f")


@pytest.fixture()
def example_action(ExampleAction):
    return accounts[0].deploy(ExampleAction)


@pytest.fixture()
def kyber_action(KyberAction):
    kyber_network_proxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
    kyber_wallet_id = "0x0000000000000000000000000000000000000000"
    return accounts[0].deploy(KyberAction, kyber_network_proxy, kyber_wallet_id)


@pytest.fixture()
def onesplit():
    # 1split.eth
    return Contract.from_explorer("0xc586bef4a0992c495cf22e1aeee4e446cecdee0e")


@pytest.fixture()
def onesplit_action(OneSplitAction):
    # TODO: does this support ENS? this is 1split.eth
    return accounts[0].deploy(OneSplitAction, "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E")


@pytest.fixture()
def owned_vault(ArgobytesOwnedVault):
    gastoken = "0x0000000000b3F879cb30FE243b4Dfee438691c04"

    # deployer = accounts[0]
    arb_bots = [accounts[1]]

    return accounts[0].deploy(ArgobytesOwnedVault, gastoken, arb_bots)


@pytest.fixture()
def uniswap_action(UniswapAction):
    uniswap_factory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"
    return accounts[0].deploy(UniswapAction, uniswap_factory)


@pytest.fixture(scope="session")
def usdc_erc20():
    return Contract.from_explorer("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")


@pytest.fixture()
def weth9_action(Weth9Action, weth9_erc20):
    return accounts[0].deploy(Weth9Action, weth9_erc20)


@pytest.fixture(scope="session")
def weth9_erc20():
    return Contract.from_explorer("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
