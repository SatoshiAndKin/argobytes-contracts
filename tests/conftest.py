import pytest
from brownie import *


@pytest.fixture(autouse=True)
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
    yield "0x0000000000000000000000000000000000000000"


@pytest.fixture()
def argobytes_atomic_trade(argobytes_owned_vault, ArgobytesAtomicTrade, gastoken):
    salt = ""
    argobytes_atomic_trade_initcode = ArgobytesAtomicTrade.deploy.encode_input()

    argobytes_atomic_trade = argobytes_owned_vault.deploy2(
        gastoken, salt, argobytes_atomic_trade_initcode, {"from": accounts[0]})

    yield ArgobytesAtomicTrade.at(argobytes_atomic_trade.return_value)


@pytest.fixture()
def argobytes_owned_vault(ArgobytesOwnedVault, ArgobytesOwnedVaultDeployer, gastoken):
    arb_bots = [accounts[1]]

    salt = ""

    # TODO: refactor for gastoken incoming
    argobytes_owned_vault_deployer_initcode = ArgobytesOwnedVaultDeployer.deploy.encode_input(salt, arb_bots)

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
def curve_fi_action(CurveFiAction, curve_fi_compound):
    curve_fi = accounts[0].deploy(CurveFiAction, accounts[0])

    # TODO: add the other exchanges
    curve_fi.saveExchange(curve_fi_compound, 2)

    yield curve_fi


@pytest.fixture(scope="session")
def dai_erc20():
    yield Contract.from_explorer("0x6b175474e89094c44da98b954eedeac495271d0f")


@pytest.fixture()
def example_action(ExampleAction):
    yield accounts[0].deploy(ExampleAction)


@pytest.fixture()
def example_action_2(ExampleAction):
    yield accounts[0].deploy(ExampleAction)


@pytest.fixture(scope="session")
def gastoken():
    # GST2: https://gastoken.io
    yield Contract.from_explorer("0x0000000000b3F879cb30FE243b4Dfee438691c04")


@pytest.fixture(scope="session")
def chi():
    # 1inch's CHI (gastoken alternative)
    yield Contract.from_explorer("0x0000000000004946c0e9F43F4Dee607b0eF1fA1c")


@pytest.fixture(scope="session")
def kollateral_invoker(ExampleAction):
    yield Contract.from_explorer("0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01")


@pytest.fixture()
def kyber_action(KyberAction, argobytes_owned_vault):
    yield accounts[0].deploy(KyberAction, accounts[0], argobytes_owned_vault)


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


@pytest.fixture(scope="session")
def onesplit_helper(address_zero, onesplit, interface):

    def inner_onesplit_helper(eth_amount, dest_token, to):
        # TODO: actual ERC20 interface
        dest_token = interface.IWETH9(dest_token)
        parts = 1
        # TODO: enable multipaths
        flags = 0

        # not sure why, but uniswap v2 is not working well
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

    yield inner_onesplit_helper


@pytest.fixture()
def onesplit_offchain_action(OneSplitOffchainAction):
    yield accounts[0].deploy(OneSplitOffchainAction)


@pytest.fixture(scope="session")
def susd_erc20():
    # # proxy_susd_bytes = web3.toBytes(text="ProxyERC20sUSD")
    # # susd_bytes = web3.toBytes(text="SynthsUSD")

    # # susd_address = synthetix_address_resolver.getAddress(susd_bytes)

    # assert susd_address == "0xae38b81459d74a8c16eaa968c792207603d84480"
    susd_address = "0xae38b81459d74a8c16eaa968c792207603d84480"
    # yield Contract.from_explorer(susd_address)

    proxy_susd_address = "0x57Ab1ec28D129707052df4dF418D58a2D46d5f51"

    yield Contract.from_explorer(proxy_susd_address, as_proxy_for=susd_address)


@pytest.fixture(scope="session")
def synthetix_address_resolver(interface):
    # this is actually the ReadProxyAddressResolver
    yield interface.IAddressResolver("0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2")


@pytest.fixture(scope="session")
def synthetix_exchange_rates(interface):
    # TODO: why isn't this working?!
    # rates_bytes = web3.toBytes(text="ExchangeRates")

    # rates = synthetix_address_resolver.getAddress(rates_bytes)

    # TODO: don't hard code
    rates = "0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77"

    yield interface.IExchangeRates(rates)


@pytest.fixture()
def synthetix_depot_action(SynthetixDepotAction):
    yield accounts[0].deploy(SynthetixDepotAction)


@pytest.fixture()
def uniswap_v1_action(UniswapV1Action):
    yield accounts[0].deploy(UniswapV1Action)


@pytest.fixture(scope="session")
def uniswap_v1_factory():
    yield Contract.from_explorer("0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95")


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

        deadline = 2000000000

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

    yield inner_uniswap_v1_helper


@pytest.fixture(scope="session")
def usdc_erc20():
    # TODO: how did etherscan figure out the proxy address?
    # https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48#readProxyContract
    yield Contract.from_explorer("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", as_proxy_for="0x0882477e7895bdc5cea7cb1552ed914ab157fe56")


@pytest.fixture()
def weth9_action(Weth9Action):
    yield accounts[0].deploy(Weth9Action)


@pytest.fixture(scope="session")
def weth9_erc20():
    yield Contract.from_explorer("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
