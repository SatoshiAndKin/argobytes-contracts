# TODO: tests for GST2 and 1inch's CHI
from brownie import *
from brownie.test import given, strategy
import pytest


def test_chi(chi):
    # TODO: why does minting anything more than 1 crash? is that some optimization they chose to make?
    # i see onchain transactions that mint far more
    value = 1

    tx = chi.mint(value, {"from": accounts[0]})

    print("gas spent:", tx.gas_used)

    balance = chi.balanceOf(accounts[0])

    print("chi balance:", balance)

    assert value == balance

    tx = chi.free(value, {"from": accounts[0]})


# @pytest.mark.xfail(reason="sometimes fails with 'out of gas'")
def test_more_chi(chi):
    # TODO: why does minting anything more than 1 crash? is that some optimization they chose to make?
    # i see onchain transactions that mint far more
    value = 50

    tx = chi.mint(value, {"from": accounts[0]})

    print("gas spent:", tx.gas_used)

    balance = chi.balanceOf(accounts[0])

    print("chi balance:", balance)

    assert value == balance

    tx = chi.free(value, {"from": accounts[0]})


@given(value=strategy('uint8', min_value=1, max_value=30))
def test_gastoken(gastoken, value):
    tx = gastoken.mint(value, {"from": accounts[0]})

    print("gas spent", tx.gas_used)

    balance = gastoken.balanceOf(accounts[0])

    print("GST2 balance:", balance)

    assert value == balance

    tx = gastoken.free(value, {"from": accounts[0]})
