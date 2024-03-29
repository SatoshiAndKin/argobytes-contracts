import os
from decimal import Decimal

from argobytes.contracts import (
    ArgobytesBrownieProject,
    get_or_create,
    load_contract,
    poke_contracts,
)
from argobytes.tokens import (
    get_balances,
    get_claimable_3crv,
    print_token_balances,
    safe_token_approve,
)


def simple_enter(account):
    """Make a bunch of transactions to deposit into leveraged cyy3crv position."""
    # TODO: we need an account with private keys
    print(f"Hello, {account}")

    min_3crv_to_claim = os.environ.get("MIN_3CRV_TO_CLAIM", 50)

    # deploy our contracts if necessary
    enter_cyy3crv_action = get_or_create(
        account, ArgobytesBrownieProject.EnterCYY3CRVAction
    )

    print("Preparing contracts...")
    # TODO: use multicall to get all the addresses?
    dai = load_contract(enter_cyy3crv_action.DAI(), account)
    usdc = load_contract(enter_cyy3crv_action.USDC(), account)
    usdt = load_contract(enter_cyy3crv_action.USDT(), account)
    threecrv = load_contract(enter_cyy3crv_action.THREE_CRV(), account)
    threecrv_pool = load_contract(
        enter_cyy3crv_action.THREE_CRV_POOL(), account, force=True
    )
    y3crv = load_contract(enter_cyy3crv_action.Y_THREE_CRV(), account)
    cyy3crv = load_contract(enter_cyy3crv_action.CY_Y_THREE_CRV(), account)
    cydai = load_contract(enter_cyy3crv_action.CY_DAI(), account)
    fee_distribution = load_contract(
        enter_cyy3crv_action.THREE_CRV_FEE_DISTRIBUTION(), account
    )
    cream = load_contract(enter_cyy3crv_action.CREAM(), account)

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv, cydai]

    poke_contracts(tokens + [threecrv_pool, fee_distribution, cream])

    # TODO: compare all these contracts with our own implementations

    balances = get_balances(account, tokens)
    print_token_balances(balances, f"{account} balances")

    claimable_3crv = get_claimable_3crv(account, fee_distribution, min_3crv_to_claim)

    # TODO: calculate/prompt for these
    min_3crv_mint_amount = 1

    # TODO: do this properly. use virtualprice and yearn's price calculation
    # print("warning! summed_balances is not actually priced in USD")
    # summed_balances = enter_data.dai + enter_data.usdc + enter_data.usdt + enter_data.threecrv + enter_data.y3crv + claimable_3crv
    # assert summed_balances > 100, "no coins"

    balances_for_3crv_pool = {
        dai: balances[dai],
        usdc: balances[usdc],
        usdt: balances[usdt],
    }

    safe_token_approve(account, balances_for_3crv_pool, threecrv_pool)

    threecrv_add_liquidity_tx = threecrv_pool.add_liquidity(
        [
            balances_for_3crv_pool[dai],
            balances_for_3crv_pool[usdc],
            balances_for_3crv_pool[usdt],
        ],
        min_3crv_mint_amount,
        {"from": account},
    )
    # threecrv_add_liquidity_tx.info()

    if claimable_3crv >= min_3crv_to_claim:
        claim_tx = fee_distribution.claim({"from": account})
        # claim_tx.info()

    # TODO: tip the developer in 3crv or ETH

    # deposit 3crv for y3crv
    balances_for_y3crv = get_balances(account, [threecrv])
    print_token_balances(balances, f"{account} balances_for_y3crv:")

    safe_token_approve(account, balances_for_y3crv, y3crv)

    y3crv_deposit_tx = y3crv.deposit(balances_for_y3crv[threecrv], {"from": account})
    # y3crv_deposit_tx.info()

    # setup cream
    markets = []
    if not cream.checkMembership(account, cyy3crv):
        markets.append(cyy3crv)
    # TODO: do we need this? is this just for borrows?
    # if not cream.checkMembership(account, cydai):
    #     markets.append(cydai)

    if markets:
        enter_markets_tx = cream.enterMarkets(markets, {"from": account})
        # enter_markets_tx.info()
    else:
        print("CREAM markets already entered")

    # deposit y3crv for cyy3crv
    balances_for_cyy3crv = get_balances(account, [y3crv])
    print_token_balances(balances_for_cyy3crv, f"{account} balances for cyy3crv:")

    safe_token_approve(account, balances_for_cyy3crv, cyy3crv)

    mint_tx = cyy3crv.mint(balances_for_cyy3crv[y3crv], {"from": account})
    # mint_tx.info()

    # TODO: need to use actual prices of 3crv and dai
    borrow_amount = int(
        balances_for_y3crv[threecrv]
        * Decimal(threecrv_pool.get_virtual_price() / 1e18 * 0.9 * 0.9)
    )
    print(f"borrow_amount: {borrow_amount}")

    assert borrow_amount > 0

    # TODO: this could be better, figute out how to properly calculate the maximum safe borrow
    balances_before_borrow = get_balances(account, tokens)
    print_token_balances(balances_before_borrow, f"{account} balances before borrow:")

    # TODO: we could use `borrow_amount` here
    (
        cream_error,
        cream_liquidity,
        cream_shortfall,
    ) = cream.getHypotheticalAccountLiquidity(account, cydai, 0, 0)

    print(f"cream_error: {cream_error}")
    print(f"cream_liquidity (before borrow): {cream_liquidity}")
    print(f"cream_shortfall: {cream_shortfall}")

    assert cream_error == 0, "cream error"
    assert cream_shortfall == 0, "cream shortfall"
    assert cream_liquidity > borrow_amount, "no cream liquidity available for borrowing"

    borrow_tx = cydai.borrow(borrow_amount, {"from": account})

    print(f"enter simple success! {borrow_tx.return_value}")

    # borrow_tx.info()

    num_events = len(borrow_tx.events)
    print(f"num events: {num_events}")

    balances = get_balances(account, tokens)
    print_token_balances(balances, f"{account} balances")

    # borrow returns non-zero on error
    assert borrow_tx.return_value == 0, "error borrowing DAI!"

    # TODO: where should these balances be?
    assert balances[cyy3crv] > 0
    assert balances[dai] == borrow_amount
