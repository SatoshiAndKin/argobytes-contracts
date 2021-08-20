import pytest
from brownie import accounts


@pytest.mark.skip(reason="these contracts are being refactored to use ArgobytesFlashBorrower")
def test_simple_arbitrage(argobytes_multicall, argobytes_trader, example_action, weth9_erc20):
    value = 1e18

    # get some WETH for accounts[1]
    weth9_erc20.deposit({"value": 2 * value, "from": accounts[1]})

    assert weth9_erc20.balanceOf(accounts[0]) == 0
    assert weth9_erc20.balanceOf(accounts[1]) == 2 * value
    assert weth9_erc20.balanceOf(example_action) == 0

    # send some WETH to accounts[0]
    weth9_erc20.transfer(accounts[0], value, {"from": accounts[1]})

    assert weth9_erc20.balanceOf(accounts[0]) == value
    assert weth9_erc20.balanceOf(accounts[1]) == value
    assert weth9_erc20.balanceOf(example_action) == 0

    # allow the proxy to use account[0]'s WETH
    weth9_erc20.approve(argobytes_trader, value, {"from": accounts[0]})

    # send some ETH to the action to simulate arbitrage profits
    weth9_erc20.transfer(example_action, value, {"from": accounts[1]})

    assert weth9_erc20.balanceOf(accounts[0]) == value
    assert weth9_erc20.balanceOf(accounts[1]) == 0
    assert weth9_erc20.balanceOf(example_action) == value

    borrows = [
        # 1 WETH from accounts[0] to example_action
        (
            value,
            weth9_erc20,
            example_action,
        ),
    ]

    # NOTE! Multicall actions do not have CallType! That is just our proxy actions! maybe need different names?
    # TODO: Multicall actions do not pass ETH. they probably should
    actions = [
        # sweep WETH
        (
            example_action,
            False,
            example_action.sweep.encode_input(accounts[0], weth9_erc20, 0),
        ),
    ]

    arbitrage_tx = argobytes_trader.atomicArbitrage(accounts[0], borrows, argobytes_multicall, actions)

    assert weth9_erc20.balanceOf(example_action) == 1
    assert weth9_erc20.balanceOf(argobytes_trader) == 0
    assert weth9_erc20.balanceOf(argobytes_multicall) == 0
    assert weth9_erc20.balanceOf(accounts[0]) == 2 * value - 1

    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong (ganache had a bug once that got us here)
    assert arbitrage_tx.status == 1

    # TODO: check logs for profits
