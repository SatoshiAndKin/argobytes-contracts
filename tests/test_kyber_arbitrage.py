import brownie
import pytest
import warnings
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @pytest.mark.xfail(reason="https://github.com/trufflesuite/ganache-core/issues/611")
def test_kyber_arbitrage(address_zero, argobytes_actor, argobytes_trader, dai_erc20, argobytes_proxy, kyber_network_proxy, kyber_action, usdc_erc20, weth9_erc20):
    assert argobytes_proxy.balance() == 0
    assert kyber_action.balance() == 0

    value = 1e18

    # get some WETH
    weth9_erc20.deposit({"value": 2 * value})

    # send some WETH to accounts[0]
    weth9_erc20.transfer(accounts[0], value)

    # allow the proxy to use account[0]'s WETH
    weth9_erc20.approve(argobytes_proxy, value, {"from": accounts[0]})

    # send some ETH to the action to simulate arbitrage profits
    weth9_erc20.transfer(kyber_action, value)

    # make sure balances match what we expect
    assert weth9_erc20.balanceOf(accounts[0]) == value
    assert weth9_erc20.balanceOf(kyber_action) == value

    borrows = [
        # 1 WETH for kyber_action
        (
            weth9_erc20,
            value,
            accounts[0],
            kyber_action,
        ),
    ]

    # TODO: WETH -> ETH via unwrap helper?
    actions = [
        # trade WETH to USDC
        (
            kyber_action,
            kyber_action.tradeTokenToToken.encode_input(
                kyber_network_proxy, kyber_action, weth9_erc20, usdc_erc20, 1, 0),
            False
        ),
        # trade USDC to ETH
        (
            kyber_action,
            kyber_action.tradeTokenToEther.encode_input(
                kyber_network_proxy, kyber_action, usdc_erc20, 1, 0),
            False
        ),
        # trade ETH to DAI
        (
            kyber_action,
            kyber_action.tradeEtherToToken.encode_input(
                kyber_network_proxy, kyber_action, dai_erc20, 1, 0),
            True
        ),
        # trade DAI to WETH
        (
            kyber_action,
            kyber_action.tradeTokenToToken.encode_input(
                kyber_network_proxy, address_zero, dai_erc20, weth9_erc20, 1, 0),
            False
        ),
    ]

    arbitrage_tx = argobytes_proxy.executeAndFree(
        False,
        False,
        argobytes_trader,
        argobytes_trader.atomicArbitrage.encode_input(
            borrows, argobytes_actor, actions
        ),
    )

    assert argobytes_proxy.balance() > value

    # TODO: https://github.com/trufflesuite/ganache-core/issues/611
    # make sure the transaction succeeded
    # there should be a revert above if status == 0, but something is wrong
    assert arbitrage_tx.status == 1
    # TODO: fetching this is crashing ganache
    # assert arbitrage_tx.return_value is not None

    # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
    # assert arbitrage_tx.return_value > 0

    # TODO: should we compare this to running without burning gas token?
    print("gas_used_with_gastoken: ", arbitrage_tx.gas_used)

    # TODO: make sure we didn't use all the gas token
