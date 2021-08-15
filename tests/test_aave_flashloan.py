from decimal import Decimal

import pytest
from brownie import accounts

from argobytes.contracts import ArgobytesBrownieProject, get_or_create, load_contract, get_or_clone_flash_borrower
from argobytes.tokens import load_token


# TODO: this fixture doesn't work because its part of eth-brownie and that isn't loaded
@pytest.mark.require_network("mainnet-fork")
def test_fake_aave_flash_loan(
    aave_registry,
    unlocked_uniswap_v2,
):
    account = accounts[0]

    aave_provider = load_contract(aave_registry.getAddressesProvidersList()[0])

    aave_lender = load_contract(aave_provider.getLendingPool())

    factory, flash_borrower, clone = get_or_clone_flash_borrower(account, [aave_registry])
    example_action = get_or_create(account, ArgobytesBrownieProject.ExampleAction)

    crv = load_token("crv", owner=account)

    start_crv = crv.balanceOf(account)

    # TODO: what amount?
    trading_crv = 1e18
    fake_arb_profits = trading_crv * 9 // 1000

    # take some tokens from uniswap
    unlocked_uniswap_v2(crv, fake_arb_profits, example_action)

    # TODO: class with useful functions to make this easier
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
