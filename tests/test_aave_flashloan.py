import click
from brownie import accounts, history

from argobytes.contracts import ArgobytesBrownieProject, get_or_clone_flash_borrower, get_or_create
from argobytes.flashloan import ArgobytesFlashManager
from argobytes.tokens import load_token


class ExampleFlashManager(ArgobytesFlashManager):
    def __init__(self, owner):
        # we are going to flash loan some WETH from Aave
        self.weth = load_token("weth", owner=owner)

        # do not replay any of the transactions before this
        start_history_index = len(history)

        # deploy action contracts
        # you probably don't want to specify salts
        self.example_action_a = get_or_create(owner, ArgobytesBrownieProject.ExampleAction, salt="a")
        self.example_action_b = get_or_create(owner, ArgobytesBrownieProject.ExampleAction, salt="b")

        # collect setup transactions from the history (if any)
        # if ExampleAction is already deployed, setup_transactions will be empty
        setup_transactions = history[start_history_index:]

        # Use delegatecall to reduce the amount of transfers.
        # You must be certain that contract does not use any state though!
        # All Argobytes Actions in contracts/actions/exchanges/*.sol are specifically designed to be delegate_callable
        delegate_callable = [
            # example_action_a is holding are simulated arb profits and so should NOT be delegate called!
            self.example_action_b,
        ]

        # a real ArgobytesFlashManager would query the blockchain to calculate the optimal trade size
        trade_size = 100e18

        super().__init__(
            owner,
            borrowed_assets={self.weth: trade_size},
            setup_transactions=setup_transactions,
            delegate_callable=delegate_callable,
        )

    def the_transactions(self):
        # a real ArgobytesFlashManager would probably call multiple actions like CurveFiAction or UniswapV2Action
        # here we just call a debugging action
        self.example_action_b.noop().info()
        self.example_action_b.burnGas(10000).info()
        # sweep the funds from ExampleAction to the clone to simulate arbitrage profits
        self.example_action_a.sweep(self.clone, self.weth, 0).info()


def test_aave_flash_loan(monkeypatch):
    owner = accounts[0]

    # TODO: set gas price?

    weth = load_token("weth", owner=owner)

    # because this is just a test, we need to fake an arbitrage opportunity
    sim_arb_profit = 9e18

    # TODO: we don't actually need to deploy the action now. we could just get the address
    example_action_a = get_or_create(owner, ArgobytesBrownieProject.ExampleAction, salt="a")

    print("preparing simulated arbitrage profit...")
    # because this arb is on the exmaple action, we MUST NOT delegate call this action
    weth.deposit({"value": sim_arb_profit, "from": owner})
    weth.transfer(example_action_a, sim_arb_profit).info()

    # we don't want to test _mainnet_send here
    monkeypatch.setattr(
        ExampleFlashManager,
        "_mainnet_send",
        lambda _self, _setup_did_something: click.secho("skipping mainnet send in tests!", fg="yellow"),
    )

    # record our starting balance for a test check at the end
    start_weth = owner.balance() + weth.balanceOf(owner)

    # BEHOLD! this is all you need to carefully do a flash loan
    # a real ArgobytesFlashManager would probably just pass the owner
    flash_manager = ExampleFlashManager(owner)
    flash_manager.careful_send(prompt_confirmation=False)
    # THAT WAS IT!

    # safety check
    # a check like this won't be needed by your real scripts because the transaction will revert if there are no profits
    end_weth = owner.balance() + weth.balanceOf(owner)

    profit = (end_weth - start_weth) / 1e18
    print(f"weth profit: {profit}")

    # TODO: if token is not weth, use a helper to include gas costs
    assert start_weth < end_weth, "bad arb!"
