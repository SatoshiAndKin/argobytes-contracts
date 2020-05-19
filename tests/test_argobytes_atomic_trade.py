import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy


def test_empty_encode_actions(argobytes_atomic_trade):
    encoded_actions = argobytes_atomic_trade.encodeActions(
        [],
        [],
    )

    print(encoded_actions)

    assert False
