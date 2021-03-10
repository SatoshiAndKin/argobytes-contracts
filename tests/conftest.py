from eth_utils import keccak, to_checksum_address, to_bytes
from eth_abi.packed import encode_abi_packed
from brownie import *
import pytest
from argobytes_util import *
from argobytes_mainnet import *


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
    return accounts[0].deploy(ArgobytesMulticall)


@pytest.fixture(scope="function")
def argobytes_authority(ArgobytesAuthority):
    return accounts[0].deploy(ArgobytesAuthority)


@pytest.fixture(scope="function")
def argobytes_factory(ArgobytesFactory):
    return accounts[0].deploy(ArgobytesFactory)


@pytest.fixture(scope="function")
def argobytes_proxy(argobytes_authority, argobytes_proxy, ArgobytesProxy, argobytes_factory):
    # on mainnet we use the (bytes32) salt to generate custom addresses, but we dont need that in our tests
    salt = ""

    deploy_tx = argobytes_factory.createClone(argobytes_proxy.address, salt, accounts[0])

    return ArgobytesProxy.at(deploy_tx.events['NewClone']['clone'], accounts[0])


@pytest.fixture(scope="function")
def argobytes_proxy(ArgobytesProxy):
    # on mainnet we use the (bytes32) salt to generate custom addresses, but we dont need that in our tests=
    return accounts[0].deploy(ArgobytesProxy)


@pytest.fixture(scope="function")
def argobytes_trader(ArgobytesTrader):
    return accounts[0].deploy(ArgobytesTrader)


@pytest.fixture(scope="session")
def cdai_erc20():
    return Contract(cDAIAddress)


@pytest.fixture(scope="session")
def chi():
    # 1inch's CHI (gastoken alternative)
    return Contract(CHIAddress)


@pytest.fixture(scope="session")
def curve_fi_3pool():
    return Contract(CurveFi3poolAddress)


@pytest.fixture(scope="session")
def curve_fi_compound():
    return Contract(CurveFiCompoundAddress)


@pytest.fixture(scope="session")
def cusdc_erc20():
    return Contract(cUSDCAddress)


@pytest.fixture(scope="function")
def curve_fi_action(CurveFiAction, curve_fi_compound):
    return accounts[0].deploy(CurveFiAction)


@pytest.fixture(scope="session")
def dai_erc20():
    return Contract(DAIAddress)


@pytest.fixture(scope="function")
def example_action(ExampleAction):
    return accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="function")
def example_action_2(ExampleAction):
    return accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="session")
def gastoken():
    return Contract(GasToken2Address)


# TODO: with a larger scope, i'm getting "This contract no longer exists"
@pytest.fixture(scope="function")
def liquidgastoken(interface):
    return interface.ILiquidGasToken(LiquidGasTokenAddress)


@pytest.fixture(scope="session")
def kollateral_invoker():
    return Contract(KollateralInvokerAddress)


@pytest.fixture(scope="function")
def kyber_action(KyberAction):
    return accounts[0].deploy(KyberAction, accounts[0])


@pytest.fixture(scope="session")
def kyber_network_proxy():
    # TODO: they have an "info" method and that is a reserved keyword
    # TODO: `return Contract(KyberNetworkProxyAddress)`
    return KyberNetworkProxyAddress


@pytest.fixture(scope="session")
def onesplit():
    # 1split.eth
    # TODO: does this support ENS? this is 1split.eth (although its probably better to have an address here)
    return Contract(OneSplitAddress)


@pytest.fixture(scope="session")
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
    return accounts[0].deploy(OneSplitOffchainAction)


@pytest.fixture(scope="session")
def susd_erc20(synthetix_address_resolver):
    # The AddressResolver is not populated with everything right now, only those internal contract addresses that do not change. ProxyERC20 (SNX) and ProxyERC20sUSD (sUSD) are static addresses you can simply hard code in if you need
    # proxy = synthetix_address_resolver.requireAndGetAddress(to_hex32(text="ProxyERC20sUSD"), "No Proxy")
    proxy = Contract(sUSDAddress)

    assert(proxy != ZERO_ADDRESS)

    return Contract(proxy, as_proxy_for=proxy.target())


@pytest.fixture(scope="session")
def synthetix_address_resolver(interface):
    # this is actually the ReadProxyAddressResolver
    proxy = Contract(SynthetixAddressResolverAddress)

    # this is the contract with the actual logic in it
    return Contract(proxy, as_proxy_for=proxy.target())

    # return interface.IAddressResolver(SynthetixAddressResolverAddress)


@pytest.fixture(scope="session")
def synthetix_exchange_rates(synthetix_address_resolver):
    rates = synthetix_address_resolver.getAddress(to_hex32(text="ExchangeRates"))

    assert(rates != ZERO_ADDRESS)

    return Contract(rates)


@pytest.fixture(scope="function")
def synthetix_depot_action(SynthetixDepotAction):
    return accounts[0].deploy(SynthetixDepotAction)


@pytest.fixture(scope="function")
def uniswap_v1_action(UniswapV1Action):
    return accounts[0].deploy(UniswapV1Action)


@pytest.fixture(scope="session")
def uniswap_v1_factory():
    return Contract(UniswapV1FactoryAddress)


@pytest.fixture(scope="function")
def uniswap_v2_action(UniswapV2Action):
    return accounts[0].deploy(UniswapV2Action)


@pytest.fixture(scope="session")
def uniswap_v2_router():
    return Contract(UniswapV2RouterAddress)


@pytest.fixture(scope="session")
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


@pytest.fixture(scope="session")
def usdc_erc20():
    # TODO: how did etherscan figure out the proxy address?
    # https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48#readProxyContract
    # TODO: better names for "USDCAddress" and "USDCProxiedAddress"
    return Contract(USDCAddress, as_proxy_for=USDCProxiedAddress)


@pytest.fixture(scope="function")
def weth9_action(Weth9Action):
    return accounts[0].deploy(Weth9Action)


@pytest.fixture(scope="session")
def weth9_erc20():
    return Contract(WETH9Address, owner=accounts[5])
