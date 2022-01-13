import click
from brownie import accounts, network

from argobytes.bundles import TransactionBundler
from argobytes.contracts import ArgobytesBrownieProject, get_or_create
from argobytes.tokens import load_token


def example_aave_flash_loan(owner):
    # we are going to flash loan some WETH from Aave
    weth = load_token("weth", owner=owner)

    # deploy action contracts
    # (don't specify salt unless you know what you are doing)
    # a real flash loan would probably want CurveFiAction or UniswapV2Action
    example_action_a = get_or_create(
        owner, ArgobytesBrownieProject.ExampleAction, salt="a"
    )
    example_action_b = get_or_create(
        owner, ArgobytesBrownieProject.ExampleAction, salt="b"
    )

    # When possible, to save gas on transfers, contracts should be designed to be delegte called.
    # You must be certain the action contract does not use any state!
    # If your acion contract is safe to delegate call, include it in the delegate_callable list
    # All Argobytes Actions in contracts/actions/exchanges/*.sol are specifically designed to be delegate_callable
    delegate_callable = [
        # example_action_a is holding the simulated arb profits and so should NOT be delegate called!
        example_action_b,
    ]

    # a real ArgobytesFlashManager would query the blockchain to calculate the optimal trade size
    trade_size = 100e18

    # this needs to be in a function so we can call it multiple times
    def transaction_bundle(bundler):
        # a real flash loan would probably call multiple actions like CurveFiAction or UniswapV2Action
        # here we just call a debugging action
        example_action_b.noop().info()
        example_action_b.burnGas(10000).info()
        # sweep the funds from ExampleAction to the clone to simulate arbitrage profits
        example_action_a.sweep(bundler.clone, weth, 0).info()

    return TransactionBundler.flashloan(
        owner,
        transaction_bundle,
        borrowed_assets={weth: trade_size},
        delegate_callable=delegate_callable,
        # a real flash loan should probably prompt confirmation
        prompt_confirmation=False,
    )


def test_aave_flash_loan(monkeypatch):
    owner = accounts[0]

    # TODO: set gas price?

    weth = load_token("weth", owner=owner)

    # because this is just a test, we need to fake an arbitrage opportunity
    # 1 wei profit (1 wei is left in each example action)
    sim_arb_profit = int(100e18 * 0.0009) + 3

    # TODO: we don't actually need to deploy the action now. we could just get the address
    example_action_a = get_or_create(
        owner, ArgobytesBrownieProject.ExampleAction, salt="a"
    )

    print("preparing simulated arbitrage profit...")
    # because this arb is on the exmaple action, we MUST NOT delegate call this action
    weth.deposit({"value": sim_arb_profit, "from": owner})
    weth.transfer(example_action_a, sim_arb_profit, {"from": owner}).info()

    # we don't want to test _mainnet_send here
    monkeypatch.setattr(
        TransactionBundler,
        "_mainnet_send",
        lambda *_: click.secho("skipping mainnet send in tests!", fg="yellow"),
    )

    # record our starting balance for a test check at the end
    start_weth = owner.balance() + weth.balanceOf(owner)

    # send the flash loan
    example_aave_flash_loan(owner)

    # safety check
    # a check like this won't be needed by your real scripts because the transaction will revert if there are no profits
    end_weth = owner.balance() + weth.balanceOf(owner)

    profit = (end_weth - start_weth) / 1e18
    print(f"weth profit: {profit}")

    # if token is not weth, be sure to include gas costs in your profit calculations!
    assert start_weth < end_weth, "bad arb!"
