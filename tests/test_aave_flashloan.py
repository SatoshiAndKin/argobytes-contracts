from brownie import accounts, history

from argobytes.contracts import ArgobytesBrownieProject, get_or_create, get_or_clone_flash_borrower
from argobytes.flashloan import ArgobytesFlashManager
from argobytes.tokens import load_token


class FlashManagerTester(ArgobytesFlashManager):

    def __init__(self, owner, token, use_delegate_call):
        # we are going to flash loan some token from Aave
        self.token = token

        # do not replay any of the transactions before this
        start_history_index = len(history)

        # deploy action contracts
        self.example_action = get_or_create(owner, ArgobytesBrownieProject.ExampleAction)

        # collect setup transactions from the history (if any)
        # if ExampleAction is already deployed, setup_transactions will be empty
        setup_transactions = history[start_history_index:]

        if use_delegate_call:
            delegate_callable = [self.example_action]
        else:
            delegate_callable = []

        super().__init__(
            owner,
            assets=[self.token],
            setup_transactions=setup_transactions,
            # if a target contract does not depend on state, delegatecall it to save needing to transfer coins to it
            delegate_callable=delegate_callable,
        )

    def the_transactions(self):
        # a real ArgobytesFlashManager would want to calculate optimal trade sizes based on  
        trading_amount = 100e18

        # send weth to the clone just like the flash loan would
        # on a forked network, we transfer from the lender
        # on mainnet, this transfer is handled by the flash loan function
        self.token.transfer(self.clone, trading_amount, {"from": self.lenders[self.token]}).info()

        # a real flash loan transaction would probably call multiple actions like CurveFiAction or UniswapV2Action
        # here, we just sweep the funds from ExampleAction to the clone to simulate profits
        self.example_action.sweep(self.clone, self.token, 0).info()


def test_aave_flash_loan():
    owner = accounts[0]

    weth = load_token("weth", owner=owner)

    # because this is just a test, we need to fake an arbitrage opportunity
    sim_arb_profit = 9e18

    # i think we will always want delegate call in prod. but having a toggle is useful when developing    
    # TODO: if we sset this to true, then the simple arb profit gets ssent to clone. but then the dry run of sweep fails
    use_delegate_call = False

    factory, flash_borrower, clone = get_or_clone_flash_borrower(
        owner,
        constructor_args=['0x52D306e36E3B6B02c153d0266ff0f85d18BCD413'],
    )
    example_action = get_or_create(owner, ArgobytesBrownieProject.ExampleAction)

    if use_delegate_call:
        # if we are going to use delegate calls, the tokens need to be on the clone
        sim_arb_to = clone
    else:
        # without delegate calls, the tokens need to be on the example action
        sim_arb_to = example_action

    print("sending simulated arbitrage profit...")
    weth.deposit({"value": sim_arb_profit})
    weth.transfer(sim_arb_to, sim_arb_profit).info()

    # record our starting balance for balance checks at the end
    start_weth = owner.balance() + weth.balanceOf(owner)

    # BEHOLD! this is all you need to call to carefully do the flash loan
    FlashManagerTester(owner, weth, use_delegate_call).careful_send(prompt_confirmation=False)

    # safety checks
    # these checks won't be needed by your real scripts. the transaction will revert if there are no profits
    end_weth = owner.balance() + weth.balanceOf(owner)

    profit = (end_weth - start_weth) / 1e18
    print(f"weth profit: {profit}")

    # TODO: if token is not weth, use a helper to include gas costs
    # alternatively, people should just start and end their arbs with ETH/WETH and accounting is much easier and depends on no oracles
    assert start_weth < end_weth, "bad arb!"
