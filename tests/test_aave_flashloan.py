from decimal import Decimal

import pytest
from brownie import accounts

from argobytes.contracts import ArgobytesBrownieProject, get_or_create, load_contract
from argobytes.tokens import load_token


# TODO: this fixture doesn't work because its part of eth-brownie and that isn't loaded
@pytest.mark.require_network("mainnet-fork")
def test_fake_aave_flash_loan(
    unlocked_uniswap_v2,
):
    account = accounts[0]

    # LendingPoolAddressesProviderRegistry
    aave_registry = load_contract("0x52D306e36E3B6B02c153d0266ff0f85d18BCD413")

    aave_flashloan = 

    aave_flashloan = get_or_clone(
        account,
        ArgobytesBrownieProject.ArgobytesAaveFlashloan,
        constructor_args=(
            account,
            aave_lender,
        ),
    )
    example_action = get_or_create(account, ArgobytesBrownieProject.ExampleAction)

    crv = load_token("crv", owner=account)
    weth = load_token("weth", owner=account)

    fake_arb_profits = Decimal(0.1)

    # take some tokens from uniswap
    unlocked_uniswap_v2(crv, fake_arb_profits, example_action)
    start_crv = crv.balanceOf(account)

    # TODO: what amount?
    trading_crv = 1e18

    # TODO: class with useful functions to make this easier
    trade_actions = []

    # sweep curve
    calldata = example_action.sweep.encode_input(
        uniswap_v2_callee,
        crv,
        0,
    )
    trade_actions.append((example_action.address, calldata))
    # sweep weth
    calldata = example_action.sweep.encode_input(
        aave_flashloan,
        weth,
        0,
    )
    trade_actions.append((example_action.address, calldata))

    # TODO: do this without a web3 call
    flash_data = uniswap_v2_callee.encodeData(trade_actions)

    if uniswap_v2_pair_eth_crv.token0() == crv:
        amount_0 = trading_crv
        amount_1 = 0
    else:
        amount_0 = 0
        amount_1 = trading_crv

    flash_tx = uniswap_v2_pair_eth_crv.swap(amount_0, amount_1, uniswap_v2_callee, flash_data)
    flash_tx.info()

    end_crv = crv.balanceOf(account)

    assert start_crv < end_crv, "bad arb!"
