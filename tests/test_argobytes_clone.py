import brownie
from brownie import ZERO_ADDRESS, accounts


# TODO: test access for all the functions!
def test_argobytes_arbitrage_access_control(argobytes_proxy_clone, example_action):
    action = (
        example_action,
        1,  # 1=Call
        False,  # do not forward ETH
        example_action.noop.encode_input(),
    )

    assert argobytes_proxy_clone.owner() == accounts[0]

    # check that accounts[0] is allowed
    argobytes_proxy_clone.execute(action, {"from": accounts[0]})

    # check that accounts[1] is NOT allowed
    # TODO: get brownie to understand typed errors in solidity 0.8
    with brownie.reverts(""):
        argobytes_proxy_clone.execute(action, {"from": accounts[1]})

    # TODO: set authority

    # TODO: check revert message if accounts[1] tries to call something

    # TODO: authorize accounts[1]

    # TODO: check that accounts[1] is allowed


def test_simple_execute(argobytes_proxy_clone, example_action):
    # call the noop function on ExampleAction
    action = (
        example_action,
        1,  # 1=Call
        False,  # do no forward ETH balance
        example_action.noop.encode_input(),
    )

    atomic_arbitrage_tx = argobytes_proxy_clone.execute(action)

    # atomic_arbitrage_tx.info()

    assert atomic_arbitrage_tx.status == 1
