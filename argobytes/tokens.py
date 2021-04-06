# TODO: this file is more than tokens. it has helpers for general contracts too

# TODO: move curve stuff back to argobytes_extra
from decimal import Decimal
from json import JSONDecodeError
from pprint import pprint
import contextlib

import brownie
import tokenlists
from eth_utils import to_checksum_address

from .contracts import EthContract, load_contract

_cache_symbols = {}
_cache_decimals = {}
_cache_token = {}


def get_claimable_3crv(account, fee_distribution, min_crv=50):
    claimable = fee_distribution.claim.call(account)

    if claimable < min_crv:
        return 0

    return claimable


def load_token(token_symbol: str):
    if token_symbol in _cache_token:
        return _cache_token[token_symbol]

    if token_symbol == "eth":
        # TODO: think about this more. this isn't a contract
        _cache_token[token_symbol] = EthContract()

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
            pass

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


def get_balances(account, tokens):
    # TODO: multicall
    # if you need ETH, use an EthContract() for the token
    return {token: token.balanceOf(account) for token in tokens}


def get_token_decimals(token_contract):
    if token_contract.address in _cache_decimals:
        return _cache_decimals[token_contract.address]

    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        decimals = 18
    elif hasattr(token_contract, "decimals"):
        decimals = token_contract.decimals()
    elif hasattr(token_contract, "DECIMALS"):
        decimals = token_contract.DECIMALS()
    else:
        raise ValueError

    decimals = Decimal(decimals)

    _cache_decimals[token_contract.address] = decimals

    return decimals


def get_token_symbol(token_contract):
    if token_contract.address in _cache_symbols:
        return _cache_symbols[token_contract.address]

    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        symbol = "ETH"
    elif hasattr(token_contract, "symbol"):
        symbol = token_contract.symbol()
    elif hasattr(token_contract, "SYMBOL"):
        symbol = token_contract.SYMBOL()
    else:
        raise ValueError

    _cache_symbols[token_contract.address] = symbol

    return symbol


def print_token_balances(balances, label=None):
    # TODO: symbol cache

    if label:
        print(label)

    dict_for_printing = dict()

    for token, amount in balances.items():
        symbol = get_token_symbol(token)

        if symbol:
            dict_for_printing[symbol] = amount
        else:
            dict_for_printing[token.address] = amount

    pprint(dict_for_printing)


def token_approve(account, balances, spender, extra_balances=None, amount=2 ** 256 - 1):
    """For every token that we have a balance of, Approve unlimited (or a specified amount) for the spender."""
    if extra_balances is None:
        extra_balances = {}

    for token, balance in balances.items():
        summed_balance = balance + extra_balances.get(token.address, 0)

        if summed_balance == 0:
            continue

        if amount is None:
            # if amount is not specified, we approve the balance
            amount = summed_balance

        allowed = token.allowance(account, spender)

        if allowed >= amount:
            print(f"No approval needed for {token.address}")
            continue
        elif allowed == 0:
            pass
        else:
            # TODO: do any of our tokens actually need this set to 0 first? maybe do this if a bool is set
            print(f"Clearing {token.address} approval...")
            _approve_tx = token.approve(spender, 0, {"from": account})

            # approve_tx.info()

        if amount == 2 ** 256 - 1:
            # the amount is the max
            print(
                f"Approving {spender} for unlimited of {account}'s {token.address}..."
            )
        else:
            # the amount was specified
            print(f"Approving {spender} for {amount} of {account}'s {token.address}...")

        approve_tx = token.approve(spender, amount, {"from": account})

        # TODO: if debug, print this
        # approve_tx.info()


def transfer_token(from_address, to, token, decimal_amount):
    """Transfer tokens from an account that we don't actually control."""
    token = load_token_or_contract(token)

    decimals = token.decimals()

    amount = int(decimal_amount * 10 ** decimals)

    token.transfer(to, amount, {"from": from_address})


@contextlib.contextmanager
def print_start_and_end_balance(account, tokens=None):
    initial_gas = account.gas_used
    starting_balance = account.balance()

    print("\nbalance of", account, ":", starting_balance / 1e18)
    print()

    if tokens:
        raise NotImplementedError("TODO: print starting token balances")

    yield

    gas_used = account.gas_used - initial_gas
    ending_balance = account.balance()

    # TODO: print the number of transactions done?
    print(f"\n{account} used {gas_used} gas.")
    print(
        f"\nspent balance of {account}:",
        (starting_balance - ending_balance) / 1e18,
        "\n",
    )

    if tokens:
        raise NotImplementedError("TODO: print ending token balances")


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
