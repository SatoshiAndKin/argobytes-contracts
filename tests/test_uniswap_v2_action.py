from hypothesis import settings
from brownie.test import given, strategy
from brownie import accounts
import pytest
import brownie


def test_action(address_zero, uniswap_v2_router, uniswap_v2_action, dai_erc20, usdc_erc20, weth9_erc20):
    value = 1e17

    distant_deadline = 100000000000

    # make sure balances match what we expect
    assert uniswap_v2_action.balance() == 0
    assert dai_erc20.balanceOf(uniswap_v2_action) == 0
    assert usdc_erc20.balanceOf(uniswap_v2_action) == 0

    # trade ETH to USDC
    # our action isn't needed for this. we just use the router directly
    uniswap_v2_router.swapExactETHForTokens(
        1,
        [weth9_erc20, usdc_erc20],
        uniswap_v2_action,
        distant_deadline,
        {"value": value, "from": accounts[0]},
    )

    # make sure USDC balance on the action is non-zero
    assert usdc_erc20.balanceOf(uniswap_v2_action) > 0

    # trade USDC to DAI
    # tradeTokenToToken(address to, address router, address[] calldata path, uint256 dest_min_tokens)
    uniswap_v2_action.tradeTokenToToken(uniswap_v2_action, uniswap_v2_router, [usdc_erc20, dai_erc20], 1)

    # make sure USDC balance on the action is zero
    assert usdc_erc20.balanceOf(uniswap_v2_action) == 0

    # make sure DAI balance is non-zero
    assert dai_erc20.balanceOf(uniswap_v2_action) > 0

    # save ETH balance for accounts[0]
    starting_eth_balance = accounts[0].balance()

    # TODO: we really should test that setting "to" to address_zero sends to msg.sender on all of them

    # trade DAI to ETH
    # tradeTokenToEther(address payable to, address exchange, address src_token, uint256 dest_min_tokens)
    uniswap_v2_action.tradeTokenToEther(accounts[0], uniswap_v2_router, [dai_erc20, weth9_erc20], 1)

    # make sure DAI balance on the action is zero (i think it will be swept back to accounts[0])
    assert dai_erc20.balanceOf(uniswap_v2_action) == 0

    # TODO: what should we assert? this is going to fail now because we don't do the sweep anymore
    assert starting_eth_balance < accounts[0].balance()
