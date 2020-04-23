import pytest
from brownie import accounts, Contract


# test isolation, always use!
# be careful though! you can still leak state in other fixtures use scope="module" or scope="session"
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


@pytest.fixture()
def atomic_trade(ArgobytesAtomicTrade, kollateral_invoker, owned_vault):
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
def kollateral_invoker(ExampleAction):
    return "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"


@pytest.fixture()
def kyber_action(KyberAction, kyber_network_proxy, kyber_wallet_id):
    return accounts[0].deploy(KyberAction, kyber_network_proxy, kyber_wallet_id)


@pytest.fixture(scope="session")
def kyber_network_proxy():
    # TODO: `return Contract.from_explorer("0x818E6FECD516Ecc3849DAf6845e3EC868087B755")`
    return "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"


@pytest.fixture(scope="session")
def kyber_wallet_id():
    # TODO: should we do the vault address? i think so. then if someone else uses our proxy, we can get some credit. but maybe we should do the KyberAction
    return "0x0000000000000000000000000000000000000000"


@pytest.fixture()
def onesplit():
    # 1split.eth
    # TODO: does this support ENS? this is 1split.eth (although its probably better to have an address here)
    return Contract.from_explorer("0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E")


@pytest.fixture()
def onesplit_onchain_action(OneSplitOnchainAction, onesplit):
    return accounts[0].deploy(OneSplitOnchainAction, onesplit)


@pytest.fixture()
def onesplit_offchain_action(OneSplitOffchainAction, onesplit):
    return accounts[0].deploy(OneSplitOffchainAction, onesplit)


@pytest.fixture(scope="session")
def gastoken():
    return Contract.from_explorer("0x0000000000b3F879cb30FE243b4Dfee438691c04")


@pytest.fixture()
def owned_vault(ArgobytesOwnedVault, gastoken):
    # deployer = accounts[0]
    arb_bots = [accounts[1]]

    return accounts[0].deploy(ArgobytesOwnedVault, gastoken, arb_bots)


@pytest.fixture()
def uniswap_action(UniswapAction, uniswap_factory):
    return accounts[0].deploy(UniswapAction, uniswap_factory)


@pytest.fixture(scope="session")
def uniswap_factory():
    return Contract.from_explorer("0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95")


@pytest.fixture(scope="session")
def usdc_erc20():
    return Contract.from_explorer("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")


@pytest.fixture()
def weth9_action(Weth9Action, weth9_erc20):
    return accounts[0].deploy(Weth9Action, weth9_erc20)


@pytest.fixture(scope="session")
def weth9_erc20():
    return Contract.from_explorer("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
