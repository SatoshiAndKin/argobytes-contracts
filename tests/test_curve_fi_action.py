from brownie import Contract


# TODO: parameterize this
def test_3pool_trade(curve_fi_action, curve_fi_3pool, onesplit_helper):
    a_id = 0
    b_id = 1

    token_a = Contract(curve_fi_3pool.coins(a_id))

    if hasattr(token_a, "target"):
        token_a = Contract(token_a, as_proxy_of=token_a.target())

    token_b = Contract(curve_fi_3pool.coins(b_id))

    if hasattr(token_b, "target"):
        token_b = Contract(token_b, as_proxy_of=token_b.target())

    # buy some DAI for the curve_fi_action
    balance_a = onesplit_helper(1e18, token_a, curve_fi_action)

    # TODO: check balances
    assert balance_a > 0

    curve_fi_action.trade(curve_fi_3pool, a_id, b_id, curve_fi_action, token_a, token_b, 1)

    # TODO: check balances

    curve_fi_action.trade(curve_fi_3pool, b_id, a_id, curve_fi_action, token_b, token_a, 1)

    # TODO: check balances
    # TODO: actually assert things


# TODO: this is failing but 3pool works. ganache-bug?
def test_compound_trade(curve_fi_action, curve_fi_compound, onesplit_helper):
    a_id = 0
    b_id = 1

    token_a = Contract(curve_fi_compound.coins(a_id))

    if hasattr(token_a, "target"):
        token_a = Contract(token_a, as_proxy_of=token_a.target())

    token_b = Contract(curve_fi_compound.coins(b_id))

    if hasattr(token_b, "target"):
        token_b = Contract(token_b, as_proxy_of=token_b.target())

    # buy some DAI for the curve_fi_action
    onesplit_helper(1e18, token_a, curve_fi_action)

    # TODO: check balances

    curve_fi_action.trade(curve_fi_compound, a_id, b_id, curve_fi_action, token_a, token_b, 1)

    # TODO: check balances

    curve_fi_action.trade(curve_fi_compound, b_id, a_id, curve_fi_action, token_b, token_a, 1)

    # TODO: check balances
    # TODO: actually assert things


def test_compound_trade_underlying(curve_fi_action, curve_fi_compound, onesplit_helper):
    a_id = 0
    b_id = 1

    token_a = Contract(curve_fi_compound.underlying_coins(a_id))

    if hasattr(token_a, "target"):
        token_a = Contract(token_a, as_proxy_of=token_a.target())

    token_b = Contract(curve_fi_compound.underlying_coins(b_id))

    if hasattr(token_b, "target"):
        token_b = Contract(token_b, as_proxy_of=token_b.target())

    # buy some DAI for the curve_fi_action
    onesplit_helper(1e18, token_a, curve_fi_action)

    # TODO: check balances

    curve_fi_action.tradeUnderlying(curve_fi_compound, a_id, b_id, curve_fi_action, token_a, token_b, 1)

    # TODO: check balances

    curve_fi_action.tradeUnderlying(curve_fi_compound, b_id, a_id, curve_fi_action, token_b, token_a, 1)

    # TODO: check balances
    # TODO: actually assert things


# TODO: test trading on other pools


# # TODO: parametrize this
# @pytest.mark.xfail(reason="bug in ganache-cli? tradeUnderlying works, so this should, too")
# def test_compound_action(curve_fi_action, curve_fi_compound, cdai_erc20, cusdc_erc20, onesplit_helper):
#     # buy some cDAI for the curve_fi_action
#     cdai_balance = onesplit_helper(1e18, cdai_erc20, curve_fi_action)

#     # TODO: get i/j from the token addresses

#     curve_fi_action.trade(CurveFiCompoundAddress, 0, 1, curve_fi_action, cdai_erc20, cusdc_erc20, 1)

#     # TODO: check balance of cusdc and cdai

#     curve_fi_action.trade(CurveFiCompoundAddress, 1, 0, curve_fi_action, cusdc_erc20, cdai_erc20, 1)
#     # TODO: check balance of cusdc and cdai
#     # TODO: actually assert things
