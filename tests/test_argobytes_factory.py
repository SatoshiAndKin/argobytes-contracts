import brownie


def test_deploy_clone(argobytes_factory, argobytes_proxy):
    tx = argobytes_factory.createClone(argobytes_proxy, "", brownie.accounts[0])

    assert len(tx.events['NewClone']) == 1
    
    assert False, "TODO: check the owner"


def test_deploy_clones(argobytes_factory, argobytes_proxy):
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

    assert False, "TODO: check the owner"

