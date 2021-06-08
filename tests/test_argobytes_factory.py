from argobytes.contracts import get_or_clone, get_or_create_factory, get_or_create_flash_borrower
from brownie import accounts


def test_get_or_clone():
    account = accounts[0]

    argobytes_factory = get_or_create_factory(account)

    argobytes_proxy = get_or_create_flash_borrower(account)

    argobytes_clone = get_or_clone(account, argobytes_factory, argobytes_proxy)

    print(argobytes_clone)

    assert False, "WIP"


def test_create_clone(argobytes_factory, argobytes_proxy):
    tx = argobytes_factory.createClone19(argobytes_proxy, "")

    # tx.info()

    assert len(tx.events["NewClone"]) == 1

    event = tx.events["NewClone"]

    assert event["target"] == argobytes_proxy
    assert event["salt"] == "0x0"
    assert event["immutable_owner"] == accounts[0]
    assert event["clone"] == tx.return_value

    # TODO: moving to solc 0.8 made our gas costs a little bit higher. investigate why
    assert tx.gas_used < 69900


def test_create_clones(argobytes_factory, argobytes_proxy):
    salts = [
        0,
        1,
        2,
        3,
    ]

    tx = argobytes_factory.createClone19s(argobytes_proxy, salts)

    # tx.info()

    assert len(tx.events["NewClone"]) == len(salts)

    event_0 = tx.events["NewClone"][0]

    assert event_0["target"] == argobytes_proxy
    assert event_0["salt"] == "0x0"
    assert event_0["immutable_owner"] == accounts[0]
    # assert event_0['clone'] == tx.return_value

    assert tx.gas_used < 70100 * len(salts)
