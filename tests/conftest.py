import pytest
from brownie import accounts

MAX_EXAMPLES = 1


# it's better to write a plugin, but this works for now
def pytest_configure():
    pytest.MAX_EXAMPLES = MAX_EXAMPLES


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
def weth9_action(Weth9Action, quick_and_dirty):
    weth9_erc20 = quick_and_dirty._weth9()

    return accounts[0].deploy(Weth9Action, weth9_erc20)
