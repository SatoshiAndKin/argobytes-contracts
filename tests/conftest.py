from eth_utils import keccak, to_checksum_address, to_bytes
from eth_abi.packed import encode_abi_packed
from brownie import *
import pytest

from argobytes import to_hex32
from argobytes.addresses import *
from argobytes.contracts import load_contract, get_or_clone, get_or_create
from argobytes.tokens import load_token_or_contract


@pytest.fixture(autouse=True, scope="function")
def isolation(fn_isolation):
    # test isolation, always use!
    # be careful though! you can still leak state in other fixtures use scope="module" or scope="session"
    pass


@pytest.fixture(autouse=True, scope="session")
def session_defaults():
    # strict bytes to protect us from ourselves
    web3.enable_strict_bytes_type_checking()


@pytest.fixture(scope="function")
def argobytes_multicall(ArgobytesMulticall):
    return get_or_create(accounts[0], ArgobytesMulticall)


@pytest.fixture(scope="function")
def argobytes_authority(ArgobytesAuthority):
    return get_or_create(accounts[0], ArgobytesAuthority)


@pytest.fixture(scope="function")
def argobytes_factory(ArgobytesFactory):
    return get_or_create(accounts[0], ArgobytesFactory)


@pytest.fixture(scope="function")
def argobytes_proxy_clone(argobytes_proxy, argobytes_factory):
    # on mainnet we use the (bytes32) salt to generate custom addresses, but we dont need that in our tests
    return get_or_clone(accounts[0], argobytes_factory, argobytes_proxy)


@pytest.fixture(scope="function")
def argobytes_proxy(ArgobytesProxy):
    # on mainnet we use the (bytes32) salt to generate custom addresses, but we dont need that in our tests=
    return get_or_create(accounts[0], ArgobytesProxy)


@pytest.fixture(scope="function")
def argobytes_trader(ArgobytesTrader):
    return get_or_create(accounts[0], ArgobytesTrader)


@pytest.fixture(scope="function")
def cdai_erc20():
    return load_contract(cDAIAddress)


@pytest.fixture(scope="function")
def curve_fi_3pool():
    return load_contract(CurveFi3poolAddress)


@pytest.fixture(scope="function")
def curve_fi_compound():
    return load_contract(CurveFiCompoundAddress)


@pytest.fixture(scope="function")
def cusdc_erc20():
    return load_contract(cUSDCAddress)


@pytest.fixture(scope="function")
def curve_fi_action(CurveFiAction, curve_fi_compound):
    return get_or_create(accounts[0], CurveFiAction)


@pytest.fixture(scope="function")
def dai_erc20():
    return load_token_or_contract("DAI")


@pytest.fixture(scope="function")
def example_action(ExampleAction):
    return get_or_create(accounts[0], ExampleAction)


@pytest.fixture(scope="function")
def example_action_2(ExampleAction):
    return get_or_create(accounts[0], ExampleAction)


@pytest.fixture(scope="function")
def enter_cyy3crv_action(EnterCYY3CRVAction):
    return get_or_create(accounts[0], EnterCYY3CRVAction)


@pytest.fixture(scope="function")
def exit_cyy3crv_action(ExitCYY3CRVAction):
    return get_or_create(accounts[0], ExitCYY3CRVAction)


@pytest.fixture(scope="function")
def kyber_action(KyberAction):
    return get_or_create(accounts[0], KyberAction, constructor_args=[accounts[0]])


@pytest.fixture(scope="function")
def kyber_network_proxy():
    # TODO: they have an "info" method and that is a reserved keyword
    # TODO: `return load_contract(KyberNetworkProxyAddress)`
    return KyberNetworkProxyAddress


@pytest.fixture(scope="function")
def onesplit():
    return load_contract("1split.eth")


@pytest.fixture(scope="function")
def onesplit_helper(onesplit, interface):

    def inner_onesplit_helper(eth_amount, dest_token, to):
        # TODO: actual ERC20 interface
        dest_token = interface.IWETH9(dest_token)
        parts = 1
        # TODO: enable multipaths
        flags = 0

        # not sure why, but uniswap v2 is not working well. i think its a ganache-core bug
        # flags += 0x1E000000  # FLAG_DISABLE_UNISWAP_V2_ALL

        expected_return = onesplit.getExpectedReturn.call(ZERO_ADDRESS, dest_token, eth_amount, parts, flags)

        expected_return_amount = expected_return[0]
        distribution = expected_return[1]

        assert(expected_return_amount > 1)

        onesplit.swap(ZERO_ADDRESS, dest_token, eth_amount, 1,
                      distribution, flags, {"from": accounts[0], "value": eth_amount})

        actual_return_amount = dest_token.balanceOf.call(accounts[0])

        if expected_return_amount != actual_return_amount:
            # TODO: actual warning?
            # TODO: why is this happening?
            print(
                f"WARNING! expected_return_amount ({expected_return_amount}) != actual_return_amount ({actual_return_amount})")

            assert(actual_return_amount > 0)

        dest_token.transfer(to, actual_return_amount, {"from": accounts[0]})

        actual_transfer_amount = dest_token.balanceOf.call(to)

        # some tokens take fees or otherwise have unexpected changes to the amount. this isn't necessarily something to raise over, but we should warn about it
        if actual_return_amount != actual_transfer_amount:
            # TODO: actual warning?
            print(
                f"WARNING! actual_return_amount ({actual_return_amount}) != actual_transfer_amount ({actual_transfer_amount})")

            assert(actual_transfer_amount > 0)

        return actual_transfer_amount

    return inner_onesplit_helper


@pytest.fixture(scope="function")
def onesplit_offchain_action(OneSplitOffchainAction):
    return get_or_create(accounts[0], OneSplitOffchainAction)


@pytest.fixture(scope="function")
def susd_erc20(synthetix_address_resolver):
    # The AddressResolver is not populated with everything right now, only those internal contract addresses that do not change. ProxyERC20 (SNX) and ProxyERC20sUSD (sUSD) are static addresses you can simply hard code in if you need
    # proxy = synthetix_address_resolver.requireAndGetAddress(to_hex32(text="ProxyERC20sUSD"), "No Proxy")
    return load_contract(sUSDAddress)


@pytest.fixture(scope="function")
def synthetix_address_resolver(interface):
    # this is actually the ReadProxyAddressResolver
    return load_contract(SynthetixAddressResolverAddress)


@pytest.fixture(scope="function")
def synthetix_exchange_rates(synthetix_address_resolver):
    rates = synthetix_address_resolver.getAddress(to_hex32(text="ExchangeRates"))

    assert(rates != ZERO_ADDRESS)

    return load_contract(rates)


@pytest.fixture(scope="function")
def uniswap_v1_action(UniswapV1Action):
    return get_or_create(accounts[0], UniswapV1Action)


@pytest.fixture(scope="function")
def uniswap_v1_factory():
    return load_contract(UniswapV1FactoryAddress)


@pytest.fixture(scope="function")
def uniswap_v2_action(UniswapV2Action):
    return get_or_create(accounts[0], UniswapV2Action)


@pytest.fixture(scope="function")
def uniswap_v2_router():
    return load_contract(UniswapV2RouterAddress)


@pytest.fixture(scope="function")
def uniswap_v1_helper(uniswap_v1_factory, interface):

    # TODO: this is reverting with an unhelpful error about JUMP
    def inner_uniswap_v1_helper(src_amount, dest_token, to):
        # get the uniswap exchange
        exchange = uniswap_v1_factory.getExchange(dest_token)

        exchange = interface.IUniswapExchange(exchange)

        # # put some ETH into the uniswap action so we can buy some DAI
        # accounts[0].transfer(uniswap_v1_action, 1e18)

        # uniswap_v1_action.tradeEtherToToken(curve_fi_action, cdai_erc20, 1, "")

        deadline = 9000000000

        tx = exchange.ethToTokenTransferInput(
            src_amount,
            deadline,
            to,
            {
                "value": src_amount,
                "from": accounts[0],
            }
        )

        return tx.return_value

    return inner_uniswap_v1_helper


@pytest.fixture(scope="function")
def unlocked_binance():
    return accounts.at("0x85b931A32a0725Be14285B66f1a22178c672d69B", force=True)


@pytest.fixture(scope="function")
def usdc_erc20():
    return load_contract(USDCAddress)


@pytest.fixture(scope="function")
def weth9_action(Weth9Action):
    return get_or_create(accounts[0], Weth9Action)


@pytest.fixture(scope="function")
def weth9_erc20():
    return load_contract(WETH9Address)
