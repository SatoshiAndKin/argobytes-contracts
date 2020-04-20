import pytest
from brownie import accounts

# test isolation, always use!
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


# TODO: open a github issue so that we can access interfaces as fixtures
@pytest.fixture(scope="module")
def quick_and_dirty(QuickAndDirty):
    return accounts[0].deploy(QuickAndDirty)


@pytest.fixture(scope="module")
def weth9_action(Weth9Action, quick_and_dirty):
    weth9_erc20 = quick_and_dirty._weth9()

    return accounts[0].deploy(Weth9Action, weth9_erc20)
