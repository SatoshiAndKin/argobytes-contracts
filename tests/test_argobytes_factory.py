import brownie


def test_deploy_clone(address_zero, argobytes_factory, argobytes_proxy):
    tx = argobytes_factory.createClone(argobytes_proxy, "", brownie.accounts[0])

    assert len(tx.events['NewClone']) == 1


def test_deploy_clones(address_zero, argobytes_factory, argobytes_proxy):
    salts = [
        0,
        1,
        2,
        3,
    ]

    tx = argobytes_factory.createClones(
        argobytes_proxy, salts,
        brownie.accounts[0]
    )

    assert len(tx.events['NewClone']) == len(salts)
