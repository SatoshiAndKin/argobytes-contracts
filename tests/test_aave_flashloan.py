from brownie import accounts

from argobytes.contracts import ArgobytesBrownieProject, get_or_create
from argobytes.flashloan import ArgobytesFlashManager
from argobytes.tokens import load_token


def test_aave_flash_loan():
    # TODO: rewrite this to 
    account = accounts[0]

    crv = load_token("crv", owner=account)

    start_crv = crv.balanceOf(account)

    # TODO: what amount?
    trading_crv = 1e18

    # TODO: put this into ArgobytesFlashManager.setup
    example_action = get_or_create(account, ArgobytesBrownieProject.ExampleAction)

    # take some CRV from the veCRV contract. simulates arb profits
    # TODO: wait. why does this pass? i thought this was the premium
    fake_arb_profits = trading_crv * 9 // 1000
    # fake_arb_profits = trading_crv
    vecrv = "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2"
    unlocked = accounts.at(vecrv, force=True)
    crv.transfer(example_action, fake_arb_profits, {"from": unlocked})

    flash_manager = ArgobytesFlashManager(
        accounts[0],
        {crv: trading_crv},
        setup_transactions=[example_action],
    )

    with flash_manager:
        # sweep curve to the clone
        example_action.sweep(
            flash_manager.clone,
            crv,
            0,
        )

    # safety checks
    end_crv = crv.balanceOf(account)
    assert start_crv < end_crv, "bad arb!"

    print("CRV profit:", (end_crv - start_crv) / 1e18)

    raise NotImplementedError("send for real")
    # TODO: not sure how to send_for_real inside tests
    # TODO: prompt for user confirmation
    # tx = flash_manager.send_for_real()
