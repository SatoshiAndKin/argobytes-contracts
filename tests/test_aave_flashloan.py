import click
from brownie import accounts, history

from argobytes.contracts import ArgobytesBrownieProject, get_or_clone_flash_borrower, get_or_create
from argobytes.flashloan import ArgobytesFlashManager
from argobytes.tokens import load_token


class ExampleFlashManager(ArgobytesFlashManager):
    def __init__(self, owner, token, use_delegate_call):
        # we are going to flash loan some token from Aave
        self.token = token

        # do not replay any of the transactions before this
        start_history_index = len(history)

        # deploy action contracts
        self.example_action_a = get_or_create(owner, ArgobytesBrownieProject.ExampleAction)
        self.example_action_b = get_or_create(owner, ArgobytesBrownieProject.ExampleAction, salt="a")

        # collect setup transactions from the history (if any)
        # if ExampleAction is already deployed, setup_transactions will be empty
        setup_transactions = history[start_history_index:]

        if use_delegate_call:
            """
            If a target contract does not depend on state, delegatecall it to save needing to transfer coins to it
            In most cases, Argobytes' actions are delegate callable.
            self.example_action_a is not in this case because it is holding our faked arbitrage profits
            """
            delegate_callable = [
                self.example_action_b,
            ]
        else:
            delegate_callable = None

        super().__init__(
            owner,
            borrowed_assets=[self.token],
            setup_transactions=setup_transactions,
            delegate_callable=delegate_callable,
        )

    def the_transactions(self):
        # a real ArgobytesFlashManager would query the blockchain to calculate the optimal trade size
        trading_amount = 100e18

        # send weth to the clone just like the flash loan would
        # on a forked network, we transfer from the lender
        # on mainnet, this transfer is handled by the flash loan function
        # every flash loan MUST include at least one transfer like this
        self.token.transfer(self.clone, trading_amount, {"from": self.lenders[self.token]}).info()

        # sweep the funds from ExampleAction to the clone to simulate profits
        # a real ArgobytesFlashManager would probably call multiple actions like CurveFiAction or UniswapV2Action
        self.example_action_b.noop().info()
        self.example_action_a.sweep(self.clone, self.token, 0).info()
        self.example_action_b.burnGas(10000).info()


def test_aave_flash_loan(monkeypatch):
    owner = accounts[0]

    weth = load_token("weth", owner=owner)

    # because this is just a test, we need to fake an arbitrage opportunity
    sim_arb_profit = 9e18

    # i think we will always want delegate call in prod. but having a toggle is useful when developing
    # TODO: if we set this to true, then the simple arb profit gets sent to clone. but then the dry run of sweep fails
    use_delegate_call = True

    factory, flash_borrower, clone = get_or_clone_flash_borrower(
        owner,
        constructor_args=["0x52D306e36E3B6B02c153d0266ff0f85d18BCD413"],
    )
    example_action = get_or_create(owner, ArgobytesBrownieProject.ExampleAction)

    print("sending simulated arbitrage profit...")
    # because this arb is on the exmaple action, we MUST NOT delegate call this action
    weth.deposit({"value": sim_arb_profit})
    weth.transfer(example_action, sim_arb_profit).info()

    # record our starting balance for balance checks at the end
    start_weth = owner.balance() + weth.balanceOf(owner)

    # we don't want to test _mainnet_send here
    monkeypatch.setattr(
        ExampleFlashManager,
        "_mainnet_send",
        lambda _self, _setup_did_something: click.secho("skipping mainnet send in tests!", fg="yellow"),
    )

    # BEHOLD! this is all you need to carefully do a flash loan
    # a real ArgobytesFlashManager would probably just pass the owner
    flash_manager = ExampleFlashManager(owner, weth, use_delegate_call)
    flash_manager.careful_send(prompt_confirmation=False)
    # THAT WAS IT!

    # safety checks
    # these checks won't be needed by your real scripts. the transaction will revert if there are no profits
    end_weth = owner.balance() + weth.balanceOf(owner)

    profit = (end_weth - start_weth) / 1e18
    print(f"weth profit: {profit}")

    # TODO: if token is not weth, use a helper to include gas costs
    # alternatively, people should just start and end their arbs with ETH/WETH and accounting is much easier and depends on no oracles
    assert start_weth < end_weth, "bad arb!"
