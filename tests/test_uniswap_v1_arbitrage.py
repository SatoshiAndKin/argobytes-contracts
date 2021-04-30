import brownie
from brownie import accounts


def test_uniswap_arbitrage(
    argobytes_multicall,
    argobytes_proxy_clone,
    argobytes_trader,
    uniswap_v1_factory,
    uniswap_v1_action,
    usdc_erc20,
    dai_erc20,
):
    assert argobytes_proxy_clone.balance() == 0
    assert argobytes_trader.balance() == 0
    assert argobytes_multicall.balance() == 0
    assert uniswap_v1_action.balance() == 0

    value = 1e18

    # send some ETH into the action to simulate arbitrage profits
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert accounts[0].balance() > value
    assert uniswap_v1_action.balance() == value
    assert argobytes_proxy_clone.balance() == 0

    usdc_exchange = uniswap_v1_factory.getExchange(usdc_erc20)
    dai_exchange = uniswap_v1_factory.getExchange(dai_erc20)

    # doesn't borrow anything because it trades ETH from the caller
    # TODO: do a test with weth9 and approvals instead
    borrows = []

    trade_actions = [
        # trade ETH to USDC
        (
            uniswap_v1_action,
            1,
            # uniswap_v1_action.tradeEtherToToken(address to, address exchange, address dest_token, uint dest_min_tokens)
            uniswap_v1_action.tradeEtherToToken.encode_input(uniswap_v1_action, usdc_exchange, usdc_erc20, 1),
        ),
        # trade USDC to DAI
        (
            uniswap_v1_action,
            0,
            # uniswap_v1_action.tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint dest_min_tokens)
            uniswap_v1_action.tradeTokenToToken.encode_input(
                uniswap_v1_action, usdc_exchange, usdc_erc20, dai_erc20, 1
            ),
        ),
        # trade DAI to ETH
        (
            uniswap_v1_action,
            0,
            # uniswap_v1_action.tradeTokenToEther(address to, address exchange, address src_token, uint dest_min_tokens)
            uniswap_v1_action.tradeTokenToEther.encode_input(argobytes_proxy_clone, dai_exchange, dai_erc20, 1),
        ),
    ]

    proxy_actions = [
        (
            argobytes_trader,
            0,
            True,
            argobytes_trader.atomicArbitrage.encode_input(
                accounts[0],
                borrows,
                argobytes_multicall,
                trade_actions,
            ),
        )
    ]  # delegatecall  # pass ETH

    owner = argobytes_proxy_clone.owner()

    assert owner == brownie.accounts[0]

    arbitrage_tx = argobytes_proxy_clone.executeMany(
        proxy_actions,
        {
            "value": value,
            "gasPrice": 0,
        },
    )

    # TODO: should we compare this to running with burning gas token?
    print("gas used: ", arbitrage_tx.gas_used)

    assert argobytes_proxy_clone.balance() > value

    # make sure the transaction succeeded
    assert arbitrage_tx.status == 1
    assert arbitrage_tx.return_value is not None

    # TODO: check event logs for profits
