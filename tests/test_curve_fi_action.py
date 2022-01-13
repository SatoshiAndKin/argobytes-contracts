from argobytes.contracts import load_contract
from argobytes.tokens import get_token_symbol


# TODO: parameterize this
def test_3pool_trade(curve_fi_action, curve_fi_3pool, unlocked_uniswap_v2):
    a_id = 0
    b_id = 1

    token_a = load_contract(curve_fi_3pool.coins(a_id))
    token_b = load_contract(curve_fi_3pool.coins(b_id))

    assert get_token_symbol(token_a) == "DAI"
    assert get_token_symbol(token_b) == "USDC"

    # send some DAI to the curve_fi_action
    unlocked_uniswap_v2(token_a, 100, curve_fi_action)

    curve_fi_action.trade(
        curve_fi_3pool, a_id, b_id, curve_fi_action, token_a, token_b, 1
    )

    # TODO: check balances

    curve_fi_action.trade(
        curve_fi_3pool, b_id, a_id, curve_fi_action, token_b, token_a, 1
    )

    # TODO: check balances
    # TODO: actually assert things


# TODO: this is failing but 3pool works. ganache-bug?
def test_compound_trade(curve_fi_action, curve_fi_compound, unlocked_uniswap_v2):
    a_id = 0
    b_id = 1

    token_a = load_contract(curve_fi_compound.coins(a_id))
    token_b = load_contract(curve_fi_compound.coins(b_id))

    assert get_token_symbol(token_a) == "cDAI"
    assert get_token_symbol(token_b) == "cUSDC"

    # send some cDAI to the curve_fi_action
    # TODO: this is cDAI and not DAI. how much should we send?
    unlocked_uniswap_v2(token_a, 100, curve_fi_action)

    assert token_a.balanceOf(curve_fi_action) == 100 * 1e8

    # TODO: compound has some issues with ganache-cli. calling mint(0) brings in some state that might fix things
    # cdai_erc20.mint(0, {"from": accounts[0]})
    # cusdc_erc20.mint(0, {"from": accounts[0]})

    curve_fi_action.trade(
        curve_fi_compound, a_id, b_id, curve_fi_action, token_a, token_b, 1
    )

    # TODO: check balances more specifically
    assert token_a.balanceOf(curve_fi_action) == 1
    assert token_b.balanceOf(curve_fi_action) > 0

    curve_fi_action.trade(
        curve_fi_compound, b_id, a_id, curve_fi_action, token_b, token_a, 1
    )

    # TODO: check balances more specifically
    assert token_a.balanceOf(curve_fi_action) > 0
    assert token_b.balanceOf(curve_fi_action) == 1

    # TODO: actually assert things


def test_compound_trade_underlying(
    curve_fi_action, curve_fi_compound, unlocked_uniswap_v2
):
    a_id = 0
    b_id = 1

    token_a = load_contract(curve_fi_compound.underlying_coins(a_id))
    token_b = load_contract(curve_fi_compound.underlying_coins(b_id))

    assert get_token_symbol(token_a) == "DAI"
    assert get_token_symbol(token_b) == "USDC"

    # send some DAI to the curve_fi_action
    unlocked_uniswap_v2(token_a, 100, curve_fi_action)

    assert token_a.balanceOf(curve_fi_action) == 100 * 1e18

    curve_fi_action.tradeUnderlying(
        curve_fi_compound, a_id, b_id, curve_fi_action, token_a, token_b, 1
    )

    # TODO: check balances

    curve_fi_action.tradeUnderlying(
        curve_fi_compound, b_id, a_id, curve_fi_action, token_b, token_a, 1
    )

    # TODO: check balances
    # TODO: actually assert things
