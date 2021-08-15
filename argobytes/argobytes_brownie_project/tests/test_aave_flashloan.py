import pytest
from brownie import accounts

from argobytes.contracts import ArgobytesBrownieProject, get_or_create, load_contract, get_or_clone_flash_borrower
from argobytes.tokens import load_token


# TODO: this fixture doesn't work because its part of eth-brownie and that isn't loaded
@pytest.mark.require_network("mainnet-fork")
def test_fake_aave_flash_loan():
    account = accounts[0]

    aave_provider_registry = load_contract("0x52D306e36E3B6B02c153d0266ff0f85d18BCD413")

    aave_provider = load_contract(aave_provider_registry.getAddressesProvidersList()[0])

    aave_lender = load_contract(aave_provider.getLendingPool(), account)

    factory, flash_borrower, clone = get_or_clone_flash_borrower(account, [aave_provider_registry])
    example_action = get_or_create(account, ArgobytesBrownieProject.ExampleAction)

    crv = load_token("crv", owner=account)

    start_crv = crv.balanceOf(account)

    # TODO: what amount?
    trading_crv = 1e18

    # take some CRV from the veCRV contract. simulates arb profits
    fake_arb_profits = trading_crv * 9 // 1000
    vecrv = "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2"
    unlocked = accounts.at(vecrv, force=True)
    crv.transfer(example_action, fake_arb_profits, {"from": unlocked})

    # TODO: class with useful functions to make creating transactions easier
    trade_actions = []

    # sweep curve to the clone
    calldata = example_action.sweep.encode_input(
        clone,
        crv,
        0,
    )
    # TODO: enum int types instead of ints
    trade_actions.append((example_action.address, 1, calldata))

    receiver_address = example_action.address
    assets = [crv]
    amounts = [trading_crv]
    modes = [0]
    on_behalf = clone
    # TODO: do this without a web3 call?
    flash_params = clone.encodeFlashParams(trade_actions)
    referral_code = 0

    flash_tx = aave_lender.flashLoan(receiver_address, assets, amounts, modes, on_behalf, flash_params, referral_code)
    flash_tx.info()

    end_crv = crv.balanceOf(account)

    assert start_crv < end_crv, "bad arb!"
