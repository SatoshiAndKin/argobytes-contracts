# TODO: this file is more than tokens. it has helpers for general contracts too

# TODO: move curve stuff back to argobytes_extra
from decimal import Decimal
from lazy_load import lazy
from eth_utils import to_checksum_address
from json import JSONDecodeError
import brownie
# import functools
import itertools
import tokenlists

from .contracts import load_contract

_cache_symbols = {}
_cache_decimals = {}
_cache_token = {}


def load_token(token_symbol: str):
    if token_symbol in _cache_token:
        return _cache_token[token_symbol]

    known_lists = tokenlists.available_token_lists()

    if not known_lists:
        known_lists = setup_tokenlists()

    token_info = None

    for tokenlist in known_lists:
        try:
            token_info = tokenlists.get_token_info(token_symbol, tokenlist)
            break
        except ValueError:
            continue

    if token_info is None:
        raise ValueError(
            f"Symbol '{token_symbol}' is not in any of our tokenlists: {known_lists}"
        )
    
    token_address = to_checksum_address(token_info.address)

    _cache_decimals[token_address] = token_info.decimals
    _cache_symbols[token_address] = token_info.symbol

    contract = load_contract(token_address)

    _cache_token[token_symbol] = contract

    return contract


def load_token_or_contract(token_symbol_or_address: str):
    try:
        return load_contract(token_symbol_or_address)
    except ValueError:
        return load_token(token_symbol_or_address)


def transfer_token(from_address, to, token, amount):
    """Transfer tokens from an account that we don't actually control."""
    decimals = token.decimals()

    amount *= 10 ** decimals

    token.transfer(to, amount, {"from": from_address})


def token_decimals(token_contract):
    if token_contract.address in _cache_decimals:
        return _cache_decimals[token_contract.address]

    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        decimals = 18
    elif hasattr(token_contract, 'decimals'):
        decimals = token_contract.decimals()
    elif hasattr(token_contract, 'DECIMALS'):
        decimals = token_contract.DECIMALS()
    else:
        raise ValueError

    decimals = Decimal(decimals)

    _cache_decimals[token_contract.address] = decimals

    return decimals


def token_symbol(token_contract):
    if token_contract.address in _cache_symbols:
        return _cache_symbols[token_contract.address]

    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        symbol = "ETH"
    elif hasattr(token_contract, 'symbol'):
        symbol = token_contract.symbol()
    elif hasattr(token_contract, 'SYMBOL'):
        symbol = token_contract.SYMBOL()
    else:
        raise ValueError

    _cache_symbols[token_contract.address] = symbol

    return symbol


def retry_fetch_token_list(url, tries=3):
    while True:
        try:
            tokenlists.install_token_list(url)
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

    return tokenlists.available_token_lists()
