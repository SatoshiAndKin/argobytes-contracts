import pytest
from brownie import accounts
from brownie.test import given, strategy


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1),
# )
def test_wrapping_and_unwrapping(quick_and_dirty, weth9_action):
    value = 1e10

    # put some ETH into the action
    accounts[0].transfer(weth9_action, value)

    # check starting balances
    assert quick_and_dirty.balance() == 0
    assert weth9_action.balance() == value
    assert quick_and_dirty.weth9_balanceOf(quick_and_dirty).return_value == 0
    assert quick_and_dirty.weth9_balanceOf(weth9_action).return_value == 0

    # do the wrapping
    weth9_action.wrap_all_to(quick_and_dirty)

    # check balances after wrapping
    assert quick_and_dirty.balance() == 0
    assert weth9_action.balance() == 0
    assert quick_and_dirty.weth9_balanceOf(
        quick_and_dirty).return_value == value
    assert quick_and_dirty.weth9_balanceOf(weth9_action).return_value == 0

    # put some WETH into the action
    assert quick_and_dirty.weth9_transfer(weth9_action, value).return_value

    # do the unwrapping
    weth9_action.unwrap_all_to(quick_and_dirty)

    # check ending balances
    assert quick_and_dirty.balance() == value
    assert weth9_action.balance() == 0
    assert quick_and_dirty.weth9_balanceOf(quick_and_dirty).return_value == 0
    assert quick_and_dirty.weth9_balanceOf(weth9_action).return_value == 0
