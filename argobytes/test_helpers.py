import brownie
import pytest
from brownie import ZERO_ADDRESS, accounts, network, project, web3
from brownie._config import CONFIG
from brownie.test.fixtures import PytestBrownieFixtures
from brownie.test.managers.runner import RevertContextManager
from click.testing import CliRunner

from argobytes.addresses import *
from argobytes.cli_helpers import get_project_root
from argobytes.contracts import (
    get_or_clone,
    get_or_create,
    get_or_create_factory,
    get_or_create_flash_borrower,
    get_or_create_proxy,
    load_contract,
)
from argobytes.tokens import load_token_or_contract, transfer_token
from argobytes.web3_helpers import to_hex32


# TODO: don't autouse, so that we can test multiple networks
@pytest.fixture(scope="session")
def brownie_mainnet_fork(pytestconfig):
    project_root = get_project_root()

    # override some config
    CONFIG.argv["revert"] = True

    # setup the project and network the same way brownie's run helper does
    brownie_project = project.load(project_root)
    brownie_project.load_config()

    network.connect("mainnet-fork")

    # TODO: brownie does some other setup for hypothesis and multiple-processes
    fixtures = PytestBrownieFixtures(pytestconfig, brownie_project)
    pytestconfig.pluginmanager.register(fixtures, "brownie-fixtures")

    brownie.reverts = RevertContextManager

    yield

    network.disconnect()


@pytest.fixture(autouse=True, scope="function")
def always(brownie_mainnet_fork, fn_isolation, monkeypatch):
    # test isolation, always use!
    fn_isolation

    # standalone mode means exceptions bubble up
    # i would put this on session scope, but monkeypatch doesn't work like that
    monkeypatch.setenv("ARGOBYTES_CLICK_STANDALONE", "0")


@pytest.fixture(autouse=True, scope="session")
def session_defaults():
    # strict bytes to protect us from ourselves
    web3.enable_strict_bytes_type_checking()


@pytest.fixture(scope="session")
def aave_provider_registry(brownie_mainnet_fork):
    return load_contract("0x52D306e36E3B6B02c153d0266ff0f85d18BCD413", accounts[0])


@pytest.fixture()
def argobytes_multicall(ArgobytesMulticall):
    return get_or_create(accounts[0], ArgobytesMulticall)


@pytest.fixture()
def argobytes_authority(ArgobytesAuthority):
    return get_or_create(accounts[0], ArgobytesAuthority)


@pytest.fixture()
def argobytes_factory():
    return get_or_create_factory(accounts[0])


@pytest.fixture()
def argobytes_proxy(ArgobytesProxy):
    # on mainnet we use the (bytes32) salt to generate custom addresses with lots of zero bytes
    # for our tests, we just need an address with the first byte being a zero
    return get_or_create_proxy(accounts[0], leading_zeros=1)


@pytest.fixture()
def argobytes_proxy_clone(argobytes_factory, argobytes_proxy):
    # on mainnet we use the (bytes32) salt to generate custom addresses, but we dont need that in our tests
    return get_or_clone(accounts[0], argobytes_factory, argobytes_proxy)


@pytest.fixture()
def argobytes_flash_borrower(aave_provider_registry, argobytes_factory, argobytes_proxy, brownie_mainnet_fork):
    # on mainnet we use the (bytes32) salt to generate custom addresses with lots of zero bytes
    # for our tests, we just need an address with the first byte being a zero
    return get_or_create_flash_borrower(accounts[0], aave_provider_registry=aave_provider_registry)


@pytest.fixture()
def argobytes_flash_clone(argobytes_factory, argobytes_flash_borrower):
    # on mainnet we use the (bytes32) salt to generate custom addresses, but we dont need that in our tests
    return get_or_clone(accounts[0], argobytes_factory, argobytes_flash_borrower)


@pytest.fixture()
def argobytes_trader(ArgobytesTrader):
    return get_or_create(accounts[0], ArgobytesTrader)


@pytest.fixture(scope="session")
def cdai_erc20():
    return load_contract(cDAIAddress)


@pytest.fixture(scope="session")
def click_test_runner():
    runner = CliRunner()

    def _click_test_runner(fn, *args, **kwargs):
        print(f"running {fn.name}...")

        result = runner.invoke(fn, *args, **kwargs)

        if result.exception:
            # TODO: option to print on success? its just getting really verbose
            print(result.stdout)
            raise result.exception

        return result

    return _click_test_runner


@pytest.fixture(scope="session")
def curve_fi_3pool(brownie_mainnet_fork):
    return load_contract(CurveFi3poolAddress)


@pytest.fixture(scope="session")
def curve_fi_compound(brownie_mainnet_fork):
    return load_contract(CurveFiCompoundAddress)


@pytest.fixture(scope="session")
def cusdc_erc20(brownie_mainnet_fork):
    return load_contract(cUSDCAddress)


@pytest.fixture()
def curve_fi_action(CurveFiAction):
    return get_or_create(accounts[0], CurveFiAction)


@pytest.fixture(scope="session")
def dai_erc20(brownie_mainnet_fork):
    return load_token_or_contract("DAI")


@pytest.fixture()
def example_action(ExampleAction):
    return get_or_create(accounts[0], ExampleAction)


@pytest.fixture()
def example_action_2(ExampleAction):
    return get_or_create(accounts[0], ExampleAction, salt=2)


@pytest.fixture()
def enter_cyy3crv_action(EnterCYY3CRVAction):
    return get_or_create(accounts[0], EnterCYY3CRVAction)


@pytest.fixture()
def exit_cyy3crv_action(ExitCYY3CRVAction):
    return get_or_create(accounts[0], ExitCYY3CRVAction)


@pytest.fixture()
def kyber_action(KyberAction, kyber_network_proxy):
    return get_or_create(accounts[0], KyberAction, constructor_args=[kyber_network_proxy, accounts[0]])


@pytest.fixture(scope="session")
def kyber_network_proxy(brownie_mainnet_fork):
    # TODO: they have an "info" method and that is a reserved keyword
    # TODO: `return load_contract(KyberNetworkProxyAddress)`
    return KyberNetworkProxyAddress


@pytest.fixture(scope="session")
def susd_erc20(brownie_mainnet_fork, synthetix_address_resolver):
    # The AddressResolver is not populated with everything right now, only those internal contract addresses that do not change. ProxyERC20 (SNX) and ProxyERC20sUSD (sUSD) are static addresses you can simply hard code in if you need
    # proxy = synthetix_address_resolver.requireAndGetAddress(to_hex32(text="ProxyERC20sUSD"), "No Proxy")
    return load_contract(sUSDAddress)


@pytest.fixture(scope="session")
def synthetix_address_resolver(brownie_mainnet_fork):
    # this is actually the ReadProxyAddressResolver
    return load_contract(SynthetixAddressResolverAddress)


@pytest.fixture(scope="session")
def synthetix_exchange_rates(brownie_mainnet_fork, synthetix_address_resolver):
    rates = synthetix_address_resolver.getAddress(to_hex32(text="ExchangeRates"))

    assert rates != ZERO_ADDRESS

    return load_contract(rates)


@pytest.fixture()
def uniswap_v1_action(UniswapV1Action):
    return get_or_create(accounts[0], UniswapV1Action)


@pytest.fixture(scope="session")
def uniswap_v1_factory(brownie_mainnet_fork):
    return load_contract(UniswapV1FactoryAddress)


@pytest.fixture()
def uniswap_v2_action(UniswapV2Action, uniswap_v2_router):
    return get_or_create(accounts[0], UniswapV2Action)


@pytest.fixture(scope="session")
def uniswap_v2_router(brownie_mainnet_fork):
    return load_contract(UniswapV2RouterAddress)


@pytest.fixture(scope="session")
def unlocked_uniswap_v2(uniswap_v2_router):
    factory = load_contract(uniswap_v2_router.factory())
    weth = load_contract(uniswap_v2_router.WETH())

    def _free_money(token_a, token_a_amount, to, token_b=weth):
        pair = factory.getPair(token_a.address, token_b.address)

        unlocked = accounts.at(pair, force=True)

        assert token_a.balanceOf(unlocked) >= token_a_amount

        return transfer_token(unlocked, to, token_a, token_a_amount)

    return _free_money


@pytest.fixture(scope="session")
def usdc_erc20(brownie_mainnet_fork):
    return load_token_or_contract("USDC")


@pytest.fixture()
def weth9_action(Weth9Action, weth9_erc20):
    return get_or_create(accounts[0], Weth9Action, constructor_args=[weth9_erc20])


@pytest.fixture(scope="session")
def weth9_erc20(brownie_mainnet_fork):
    return load_contract(WETH9Address)
