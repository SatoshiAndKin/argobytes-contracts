# example test from the docs
from brownie import accounts


def test_account_balance():
    balance = accounts[0].balance()
    accounts[0].transfer(accounts[1], "10 ether", gas_price=0)

    assert balance - "10 ether" == accounts[0].balance()
