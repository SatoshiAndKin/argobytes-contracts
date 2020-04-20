# TODO: max_examples should not be 1, but tests are slow with the default while developing

import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings

# we use the zero address for ETH
zero_address = "0x0000000000000000000000000000000000000000"


@given(
    value=strategy('uint256', max_value=1e18, min_value=1),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_access_control(example_action, atomic_trade, owned_vault, value):
    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)

    # encode a simple action that only sweeps funds
    encoded_actions = atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(zero_address)],
    )
    print("encoded_actions: ", encoded_actions)

    with brownie.reverts("ArgobytesOwnedVault: Caller is not trusted"):
        owned_vault.atomicArbitrage(
            [zero_address], value, encoded_actions, {'from': accounts[0]})


@given(
    value=strategy('uint256', max_value=1e18, min_value=1),
)
@settings(max_examples=pytest.MAX_EXAMPLES)
def test_simple_borrow_and_sweep(value, atomic_trade, owned_vault, example_action):
    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)

    # TODO: i don't like having to encode lke this
    encoded_actions = atomic_trade.encodeActions(
        [example_action],
        [example_action.sweep.encode_input(zero_address)],
    )

    # accounts[1] is setup as the default trusted bot
    atomic_arbitrage_tx = owned_vault.atomicArbitrage(
        [zero_address], value, encoded_actions, {'from': accounts[1]})

    print(atomic_arbitrage_tx)

    profit = atomic_arbitrage_tx.return_value

    ending_balance = owned_vault.balance()

    assert ending_balance == value

# it("... should fail if using kollateral and not enough profit", async ()=> {
#     const aovInstance=await ArgobytesOwnedVault.deployed()
#     const aaaInstance=await ArgobytesAtomicArbitrage.deployed()
#     const exampleActionInstance=await ExampleAction.deployed()

#     let simulatedArbAmount=100000

#     // give some tokens to the example action. this is NOT a realistic scenario, but it is an easy way to simulate an arbitrage opportunity
#     await exampleActionInstance.send(simulatedArbAmount)

#     // this sweep call will give us back all our tokens, plus simulatedArbAmount
#     let exampleSweepCalldata=exampleActionInstance.contract.methods.sweep("0x0000000000000000000000000000000000000000").encodeABI()

#     let encoded_actions=await aaaInstance.encodeActions(
#         [exampleActionInstance.address],
#         [exampleSweepCalldata]
#     )

#     let starting_balance=await web3.eth.getBalance(aovInstance.address)
#     assert.isAbove(parseInt(starting_balance), 1000000)

#     if (global.mode == "profile") global.profilerSubprovider.start()

#     // use more than our starting balance so that we borrow some from kollateral
#     // TODO: this is supposed to revert! how do we catch that?
#     await aovInstance.atomicArbitrage(["0x0000000000000000000000000000000000000000"], starting_balance + 1, encoded_actions)

#     if (global.mode == "profile") global.profilerSubprovider.stop()

#     let ending_balance=await web3.eth.getBalance(aovInstance.address)

#     // TODO: this is starting balance + simulatedArbAmount - kollateral fee
#     assert.isAbove(parseInt(ending_balance), parseInt(starting_balance))
# })
