import pytest
from brownie import *

# TODO: it's dangerous out there. take this
# import pdb
# pdb.set_trace()

# test isolation, always use!
# be careful though! you can still leak state in other fixtures use scope="module" or scope="session"


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


@pytest.fixture()
def atomic_trade(ArgobytesAtomicTrade, kollateral_invoker, owned_vault):
    atomic_trade_instance = accounts[0].deploy(ArgobytesAtomicTrade, kollateral_invoker, owned_vault)

    owned_vault.setArgobytesAtomicTrade(atomic_trade_instance)

    yield atomic_trade_instance


@pytest.fixture()
def curve_fi_action(CurveFiAction):
    curve_compounded = "0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56"
    curve_n = 2

    yield accounts[0].deploy(CurveFiAction, curve_compounded, curve_n)


@pytest.fixture(scope="session")
def dai_erc20():
    yield Contract.from_explorer("0x6b175474e89094c44da98b954eedeac495271d0f")


@pytest.fixture()
def example_action(ExampleAction):
    yield accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="session")
def gastoken():
    yield Contract.from_explorer("0x0000000000b3F879cb30FE243b4Dfee438691c04")


@pytest.fixture()
def kollateral_invoker(ExampleAction):
    yield "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"


@pytest.fixture()
def kyber_action(KyberAction, kyber_network_proxy, kyber_wallet_id):
    yield accounts[0].deploy(KyberAction, kyber_network_proxy, kyber_wallet_id)


@pytest.fixture(scope="session")
def kyber_network_proxy():
    # TODO: they have an "info" method and that is a reserved keyword
    # TODO: `return Contract.from_explorer("0x818E6FECD516Ecc3849DAf6845e3EC868087B755")`
    yield "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"


@pytest.fixture(scope="session")
def kyber_wallet_id():
    # TODO: should we do the vault address? i think so. then if someone else uses our proxy, we can get some credit. but maybe we should do the KyberAction
    yield "0x0000000000000000000000000000000000000000"


@pytest.fixture()
def onesplit():
    # 1split.eth
    # TODO: does this support ENS? this is 1split.eth (although its probably better to have an address here)
    yield Contract.from_explorer("0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E")


@pytest.fixture()
def onesplit_onchain_action(OneSplitOnchainAction, onesplit):
    yield accounts[0].deploy(OneSplitOnchainAction, onesplit)


@pytest.fixture()
def onesplit_offchain_action(OneSplitOffchainAction, onesplit):
    yield accounts[0].deploy(OneSplitOffchainAction, onesplit)


@pytest.fixture()
def owned_vault(ArgobytesOwnedVault, gastoken):
    # deployer = accounts[0]
    arb_bots = [accounts[1]]

    yield accounts[0].deploy(ArgobytesOwnedVault, gastoken, arb_bots)


@pytest.fixture(scope="session")
def susd_erc20():
    yield Contract.from_explorer("0x57ab1ec28d129707052df4df418d58a2d46d5f51")


@pytest.fixture(scope="session")
def synthetix_address_resolver():
    yield Contract.from_explorer("0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2")


@pytest.fixture()
def synthetix_depot_action(SynthetixDepotAction, synthetix_address_resolver):
    yield accounts[0].deploy(SynthetixDepotAction, synthetix_address_resolver)


@pytest.fixture()
def uniswap_action(UniswapAction, uniswap_factory):
    yield accounts[0].deploy(UniswapAction, uniswap_factory)


@pytest.fixture(scope="session")
def uniswap_factory():
    yield Contract.from_explorer("0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95")


@pytest.fixture(scope="session")
def usdc_erc20():
    # TODO: how did etherscan figure out the proxy address?
    # https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48#readProxyContract
    yield Contract.from_explorer("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", as_proxy_for="0x0882477e7895bdc5cea7cb1552ed914ab157fe56")


@pytest.fixture()
def weth9_action(Weth9Action, weth9_erc20):
    yield accounts[0].deploy(Weth9Action, weth9_erc20)


@pytest.fixture(scope="session")
def weth9_erc20():
    yield Contract.from_explorer("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
