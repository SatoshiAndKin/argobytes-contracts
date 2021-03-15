# TODO: this file is more than tokens. it has helpers for general contracts too

# TODO: move curve stuff back to argobytes_extra
from decimal import Decimal
from lazy_load import lazy
from json import JSONDecodeError
import brownie
# import functools
import itertools
import tokenlists

from .contracts import load_contract


def transfer_token(from_address, to, token, amount):
    """Transfer tokens from an account that we don't actually control."""
    decimals = token.decimals()

    amount *= 10 ** decimals

    token.transfer(to, amount, {"from": from_address})


def token_decimals(token_contract):
    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        return 18

    # TODO: how should we handle ETH?
    if hasattr(token_contract, 'decimals'):
        return Decimal(token_contract.decimals())

    if hasattr(token_contract, 'DECIMALS'):
        return Decimal(token_contract.DECIMALS())

    raise ValueError


def retry_fetch_token_list(url, tries=3):
    while True:
        try:
            tokenlists.fetch_token_list(url)
        except JSONDecodeError:
            tries -= 1

            if tries <= 0:
                raise

            print(f"Warning! Failed fetching {url}. {tries} tries left")
        else:
            return


def setup_tokenlists(lists_to_try=None, default_list=None):
    if lists_to_try is None:
        lists_to_try = [
            "tokens.1inch.eth",
            "https://tokens.coingecko.com/uniswap/all.json",
            "synths.snx.eth",
            "wrapped.tokensoft.eth",
        ]
        if default_list is None:
            default_list = "CoinGecko"

    for list_to_try in lists_to_try:
        retry_fetch_token_list(list_to_try)

    if default_list:
        tokenlists.set_default_token_list(default_list)
