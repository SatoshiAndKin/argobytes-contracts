from brownie import accounts


def test_deploy_clone(argobytes_factory, argobytes_proxy):
    tx = argobytes_factory.createClone(argobytes_proxy, "", accounts[0])

    tx.info()

    assert len(tx.events['NewClone']) == 1
    
    event = tx.events['NewClone']

    assert event['target'] == argobytes_proxy
    assert event['salt'] == "0x0"
    assert event['immutable_owner'] == accounts[0]
    assert event['clone'] == tx.return_value

    assert tx.gas_used < 70000


def test_deploy_clones(argobytes_factory, argobytes_proxy):
    salts = [
        0,
        1,
        2,
        3,
    ]

    tx = argobytes_factory.createClones(
        argobytes_proxy, salts,
        accounts[0]
    )

    tx.info()

    assert len(tx.events['NewClone']) == len(salts)

    event_0 = tx.events['NewClone'][0]

    assert event_0['target'] == argobytes_proxy
    assert event_0['salt'] == "0x0"
    assert event_0['immutable_owner'] == accounts[0]
    # assert event_0['clone'] == tx.return_value

    assert tx.gas_used < 70000 * len(salts)

