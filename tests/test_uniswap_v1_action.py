from brownie import ZERO_ADDRESS, accounts


def test_get_exchange_weth9(uniswap_v1_factory, weth9_erc20):
    exchange = uniswap_v1_factory.getExchange.call(weth9_erc20)
    print("exchange:", exchange)

    assert exchange != ZERO_ADDRESS


def test_get_exchange_failure(uniswap_v1_factory):
    exchange = uniswap_v1_factory.getExchange.call(ZERO_ADDRESS)
    print("exchange:", exchange)

    assert exchange == ZERO_ADDRESS


# @pytest.mark.xfail(reason="test passes when its run by itself, but it fails when everything is run together. bug in test isolation? bug in ganache-cli?")
def test_action(uniswap_v1_factory, uniswap_v1_action, dai_erc20, usdc_erc20):
    value = 1e17

    # send some ETH into the action
    accounts[0].transfer(uniswap_v1_action, value)

    # make sure balances match what we expect
    assert uniswap_v1_action.balance() == value

    usdc_exchange = uniswap_v1_factory.getExchange(usdc_erc20)
    dai_exchange = uniswap_v1_factory.getExchange(dai_erc20)

    # trade ETH to USDC
    # tradeEtherToToken(address to, address exchange, address dest_token, uint256 dest_min_tokens)
    uniswap_v1_action.tradeEtherToToken(uniswap_v1_action, usdc_exchange, usdc_erc20, 1)

    # make sure ETH balance on the action is zero (it will be swept back to accounts[0])
    assert uniswap_v1_action.balance() == 0

    # make sure USDC balance on the action is non-zero
    assert usdc_erc20.balanceOf(uniswap_v1_action) > 0

    # trade USDC to DAI
    # tradeTokenToToken(address to, address exchange, address src_token, address dest_token, uint256 dest_min_tokens)
    uniswap_v1_action.tradeTokenToToken(uniswap_v1_action, usdc_exchange, usdc_erc20, dai_erc20, 1)

    # make sure USDC balance on the action is zero
    assert usdc_erc20.balanceOf(uniswap_v1_action) == 0

    # make sure DAI balance is non-zero
    assert dai_erc20.balanceOf(uniswap_v1_action) > 0

    # save ETH balance for accounts[0]
    starting_eth_balance = accounts[0].balance()

    # TODO: we really should test that setting "to" to ZERO_ADDRESS sends to msg.sender on all of them

    # trade DAI to ETH
    # tradeTokenToEther(address payable to, address exchange, address src_token, uint256 dest_min_tokens)
    uniswap_v1_action.tradeTokenToEther(accounts[0], dai_exchange, dai_erc20, 1)

    # make sure DAI balance on the action is zero (i think it will be swept back to accounts[0])
    assert dai_erc20.balanceOf(uniswap_v1_action) == 0

    # make sure ETH balance increased for accounts[0]
    assert starting_eth_balance < accounts[0].balance()
