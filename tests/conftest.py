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
def argobytes_atomic_trade(ArgobytesAtomicTrade):
    # TODO: use argobytes_owned_vault.deploy2(...) instead
    yield accounts[0].deploy(ArgobytesAtomicTrade)


@pytest.fixture()
def argobytes_owned_vault(ArgobytesOwnedVault, ArgobytesOwnedVaultDeployer, gastoken):
    arb_bots = [accounts[1]]

    salt = ""

    # TODO: refactor for gastoken incoming
    argobytes_owned_vault_deployer_initcode = ArgobytesOwnedVaultDeployer.deploy.encode_input(salt, gastoken, arb_bots)

    # we don't use the normal deploy function because the contract selfdestructs after deploying ArgobytesOwnedVault
    argobytes_owned_vault_tx = accounts[0].transfer(data=argobytes_owned_vault_deployer_initcode)

    # TODO: is this the best way to get an address out? i feel like it should already be in logs
    # argobytes_owned_vault = argobytes_owned_vault_tx.events["Deployed"]["argobytes_owned_vault"]
    argobytes_owned_vault = argobytes_owned_vault_tx.logs[0]['address']

    yield ArgobytesOwnedVault.at(argobytes_owned_vault)


@pytest.fixture(scope="session")
def cdai_erc20():
    yield Contract.from_explorer("0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643")


@pytest.fixture(scope="session")
def cusdc_erc20():
    yield Contract.from_explorer("0x39aa39c021dfbae8fac545936693ac917d5e7563")


@pytest.fixture(scope="session")
def curve_fi_compound(CurveFiAction):
    yield Contract.from_explorer("0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56")


@pytest.fixture()
def curve_fi_compound_action(CurveFiAction, curve_fi_compound):
    curve_n = 2

    yield accounts[0].deploy(CurveFiAction, curve_fi_compound, curve_n)


@pytest.fixture(scope="session")
def dai_erc20():
    yield Contract.from_explorer("0x6b175474e89094c44da98b954eedeac495271d0f")


@pytest.fixture()
def example_action(ExampleAction):
    yield accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="session")
def gastoken():
    yield Contract.from_explorer("0x0000000000b3F879cb30FE243b4Dfee438691c04")


@pytest.fixture(scope="session")
def kollateral_invoker(ExampleAction):
    yield Contract.from_explorer("0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01")


@pytest.fixture()
def kyber_action(KyberAction, kyber_network_proxy, argobytes_owned_vault):
    yield accounts[0].deploy(KyberAction, kyber_network_proxy, argobytes_owned_vault)


@pytest.fixture(scope="session")
def kyber_network_proxy():
    # TODO: they have an "info" method and that is a reserved keyword
    # TODO: `return Contract.from_explorer("0x818E6FECD516Ecc3849DAf6845e3EC868087B755")`
    yield "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"


@pytest.fixture(scope="session")
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


@pytest.fixture(scope="session")
def susd_erc20():
    yield Contract.from_explorer("0x57ab1ec28d129707052df4df418d58a2d46d5f51")


@pytest.fixture(scope="session")
def synthetix_address_resolver():
    # this is actually the ReadProxyAddressResolver
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
