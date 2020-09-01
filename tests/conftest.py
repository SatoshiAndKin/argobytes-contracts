import pytest
from argobytes_util import *
from argobytes_mainnet import *
from brownie import *
from eth_abi.packed import encode_abi_packed
from eth_utils import keccak, to_checksum_address, to_bytes


@pytest.fixture(autouse=True, scope="function")
def isolation(fn_isolation):
    # test isolation, always use!
    # be careful though! you can still leak state in other fixtures use scope="module" or scope="session"
    pass


@pytest.fixture(autouse=True, scope="session")
def session_defaults():
    # strict bytes to protect us from ourselves
    web3.enable_strict_bytes_type_checking()


@pytest.fixture(scope="session")
def address_zero():
    return "0x0000000000000000000000000000000000000000"


@pytest.fixture(scope="function")
def argobytes_atomic_trade(ArgobytesAtomicActions):
    return ArgobytesAtomicActions.deploy({"from": accounts[0]})


@pytest.fixture(scope="function")
def argobytes_diamond(address_zero, ArgobytesOwnedVault, DiamondCreator):
    # on mainnet we use the (hex) salt to generate custom addresses, but we dont need that in our tests
    salt = ""

    # deploy the contract that will deploy the diamond (and cutter and loupe)
    # it self destructs, so handling it is non-standard
    diamond_deploy_tx = DiamondCreator.deploy(
        address_zero,
        salt,
        salt,
        salt,
        {"from": accounts[0]}
    )

    # deploys have no return_value, so we check logs instead
    diamond_address = diamond_deploy_tx.logs[0]['address']

    argobytes_diamond = interface.IArgobytesDiamond(diamond_address)

    gas_price = 0

    # deploy ArgobytesOwnedVault and add it to the diamond
    argobytes_owned_vault = deploy2_and_cut_and_free(
        address_zero,
        argobytes_diamond,
        salt,
        ArgobytesOwnedVault,
        [],
        ["atomicArbitrage", "atomicTrades", "delegateAtomicActions", "delegateCall", "withdrawTo"],
        gas_price
    )

    # allow accounts[1] to do arbitrage trades
    TRUSTED_ARBITRAGER_ROLE = argobytes_owned_vault.TRUSTED_ARBITRAGER_ROLE()

    # TODO: do this with gas token freeing
    argobytes_diamond.grantRole(TRUSTED_ARBITRAGER_ROLE, accounts[1], {"from": accounts[0]})

    # TODO: eventually we will have something like this
    # TODO: we will need to make sure that replacing withdrawTo works properly
    # argobytes_tokenized_deposits = deploy2_and_cut_and_free(
    #     gas_token,
    #     argobytes_diamond,
    #     salt,
    #     ArgobytesTokenizedDeposits,
    #     [],
    #     ["deposit", "depositFor", "approve", "permit", "withdraw", "withdrawTo"],
    #     expected_mainnet_gas_price,
    #     gas_price
    # )

    return argobytes_diamond


@pytest.fixture(scope="session")
def cdai_erc20():
    return Contract.from_explorer(cDAIAddress)


@pytest.fixture(scope="session")
def chi():
    # 1inch's CHI (gastoken alternative)
    return Contract.from_explorer(CHIAddress)


@pytest.fixture(scope="session")
def cusdc_erc20():
    return Contract.from_explorer(cUSDCAddress)


@pytest.fixture(scope="session")
def curve_fi_compound(CurveFiAction):
    return Contract.from_explorer(CurveFiCompoundAddress)


@pytest.fixture(scope="function")
def curve_fi_action(CurveFiAction, curve_fi_compound):
    curve_fi = accounts[0].deploy(CurveFiAction, accounts[0])

    # TODO: add the other exchanges
    curve_fi.saveExchange(curve_fi_compound, 2)

    return curve_fi


@pytest.fixture(scope="session")
def dai_erc20():
    return Contract.from_explorer(DAIAddress)


@pytest.fixture(scope="function")
def example_action(ExampleAction):
    return accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="function")
def example_action_2(ExampleAction):
    return accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="session")
def gastoken():
    return Contract.from_explorer(GasToken2Address)


# TODO: with a larger scope, i'm getting "This contract no longer exists"
@pytest.fixture(scope="function")
def liquidgastoken(interface):
    return interface.ILiquidGasToken(LiquidGasTokenAddress)


@pytest.fixture(scope="session")
def kollateral_invoker():
    return Contract.from_explorer(KollateralInvokerAddress)


# TODO: diamond instead of argobytes_owned_vault
@pytest.fixture(scope="function")
def kyber_action(KyberAction):
    return accounts[0].deploy(KyberAction)


@pytest.fixture(scope="session")
def kyber_network_proxy():
    # TODO: they have an "info" method and that is a reserved keyword
    # TODO: `return Contract.from_explorer(KyberNetworkProxyAddress)`
    return KyberNetworkProxyAddress


@pytest.fixture(scope="session")
def onesplit():
    # 1split.eth
    # TODO: does this support ENS? this is 1split.eth (although its probably better to have an address here)
    return Contract.from_explorer(OneSplitAddress)


@pytest.fixture(scope="session")
def onesplit_helper(address_zero, onesplit, interface):

    def inner_onesplit_helper(eth_amount, dest_token, to):
        # TODO: actual ERC20 interface
        dest_token = interface.IWETH9(dest_token)
        parts = 1
        # TODO: enable multipaths
        flags = 0

        # not sure why, but uniswap v2 is not working well. i think its a ganache-core bug
        flags += 0x1E000000  # FLAG_DISABLE_UNISWAP_V2_ALL

        expected_return = onesplit.getExpectedReturn(address_zero, dest_token, eth_amount, parts, flags)

        expected_return_amount = expected_return[0]
        distribution = expected_return[1]

        onesplit.swap(address_zero, dest_token, eth_amount, 1,
                      distribution, flags, {"from": accounts[0], "value": eth_amount})

        # TODO: this feels too greedy. but it probably works for now. why can't we just use expected_return_amount?
        actual_return_amount = dest_token.balanceOf.call(accounts[0])

        if expected_return_amount != actual_return_amount:
            # TODO: actual warning?
            print(
                f"WARNING! expected_return_amount ({expected_return_amount}) != actual_return_amount ({actual_return_amount})")

        # TODO: safeTransfer?
        dest_token.transfer(to, actual_return_amount, {"from": accounts[0]})

        actual_transfer_amount = dest_token.balanceOf.call(to)

        # some tokens take fees or otherwise have unexpected changes to the amount. this isn't necessarily something to raise over, but we should warn about it
        if expected_return_amount != actual_transfer_amount:
            # TODO: actual warning?
            print(
                f"WARNING! expected_return_amount ({expected_return_amount}) != actual_return_amount ({actual_return_amount})")

        return actual_transfer_amount

    return inner_onesplit_helper


@pytest.fixture(scope="function")
def onesplit_offchain_action(OneSplitOffchainAction):
    return accounts[0].deploy(OneSplitOffchainAction)


@pytest.fixture(scope="session")
def susd_erc20():
    # TODO: web3.toPaddedBytes
    # # proxy_susd_bytes = web3.toBytes(text="ProxyERC20sUSD")
    # # susd_bytes = web3.toBytes(text="SynthsUSD")

    # # susd_address = synthetix_address_resolver.getAddress(susd_bytes)

    # assert susd_address == sUSDAddress

    return Contract.from_explorer(ProxysUSDAddress, as_proxy_for=sUSDAddress)


@pytest.fixture(scope="session")
def synthetix_address_resolver(interface):
    # this is actually the ReadProxyAddressResolver
    return interface.IAddressResolver(SynthetixAddressResolverAddress)


@pytest.fixture(scope="session")
def synthetix_exchange_rates(interface):
    # TODO: use padded bytes
    # rates_bytes = web3.toBytes(text="ExchangeRates")

    # rates = synthetix_address_resolver.getAddress(rates_bytes)

    rates = SynthetixExchangeRatesAddress

    return interface.IExchangeRates(rates)


@pytest.fixture(scope="function")
def synthetix_depot_action(SynthetixDepotAction):
    return accounts[0].deploy(SynthetixDepotAction)


@pytest.fixture(scope="function")
def uniswap_v1_action(UniswapV1Action):
    return accounts[0].deploy(UniswapV1Action)


@pytest.fixture(scope="session")
def uniswap_v1_factory():
    return Contract.from_explorer(UniswapV1FactoryAddress)


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
    return Contract.from_explorer(USDCAddress, as_proxy_for=USDCProxiedAddress)


@pytest.fixture(scope="function")
def weth9_action(Weth9Action):
    return accounts[0].deploy(Weth9Action)


@pytest.fixture(scope="session")
def weth9_erc20():
    return Contract.from_explorer(Weth9Address)
