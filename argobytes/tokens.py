# TODO: this file is more than tokens. it has helpers for general contracts too

# TODO: move curve stuff back to argobytes_extra
import contextlib
from decimal import Decimal
from json import JSONDecodeError
from pprint import pprint

import brownie
import tokenlists
from eth_utils import to_checksum_address, is_address

from .contracts import EthContract, load_contract

_cache_symbols = {}
_cache_decimals = {}
_cache_token = {}


def get_claimable_3crv(account, fee_distribution, min_crv=50):
    claimable = fee_distribution.claim.call(account)

    if claimable < min_crv:
        return 0

    return claimable


def load_token(token_symbol: str, block=None, owner=None):
    assert token_symbol, "No token symbol give to look up"

    if token_symbol in _cache_token:
        token = _cache_token[token_symbol]
        token._owner = owner
        return token

    if token_symbol.lower() == "eth":
        # TODO: think about this more. this isn't a contract
        _cache_token[token_symbol] = EthContract()

        return _cache_token[token_symbol]

    # TODO: allow specifying a token list
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

    contract = load_contract(token_address, block=block, owner=owner)

    _cache_token[token_symbol] = contract

    return contract


def load_token_or_contract(
    token_symbol_or_address: str, block=None, fallback_interface=None
):
    if hasattr(token_symbol_or_address, "address"):
        # this is already a contract
        return token_symbol_or_address

    if token_symbol_or_address == "ETH":
        # TODO: go back to treating this as WETH (except that broke balance checks)
        return EthContract()

    # treat BTC as WBTC
    # doing this for ETH caused some problems, but i think this will be fine
    if token_symbol_or_address == "BTC":
        token_symbol_or_address == "WBTC"

    if is_address(token_symbol_or_address):
        try:
            return load_contract(token_symbol_or_address, block=block)
        except Exception:
            if not fallback_interface:
                raise

        return fallback_interface(token_symbol_or_address)

    return load_token(token_symbol_or_address, block=block)


def get_balances(account, tokens):
    # TODO: multicall
    # if you need ETH, use an EthContract() for the token
    return {token: Decimal(token.balanceOf(account)) for token in tokens}


def get_decimal_shift(token):
    if isinstance(token, int):
        decimals = token
    else:
        decimals = get_token_decimals(token)

    return Decimal(10 ** decimals)


def get_token_decimals(token_contract):
    if hasattr(token_contract, "address") and token_contract.address in _cache_decimals:
        return _cache_decimals[token_contract.address]

    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        # ETH is not an ERC20
        decimals = 18
    elif token_contract.address == "0x57Ab1E02fEE23774580C119740129eAC7081e9D3":
        # old sUSD contract
        decimals = 18
    elif token_contract.address == "0xC011A72400E58ecD99Ee497CF89E3775d4bd732F":
        # this is a proxy to a proxy to a gnosis safe
        decimals = 18
    elif token_contract.address == "0xE215e8160a5e0A03f2D6c7900b050F2f04eA5Cbb":
        # RAY is weird
        decimals = 0
    elif token_contract.address == "0x000000000000C1CB11D5c062901F32D06248CE48":
        decimals = 0
    else:
        if hasattr(token_contract, "decimals"):
            decimals_fn = token_contract.decimals
        elif hasattr(token_contract, "DECIMALS"):
            decimals_fn = token_contract.DECIMALS
        else:
            raise ValueError

        if hasattr(decimals_fn, "call"):
            # some contracts forgot to add "view" to their functions and so we need to call
            decimals = decimals_fn.call()
        else:
            decimals = decimals_fn()

    decimals = Decimal(decimals)

    _cache_decimals[token_contract.address] = decimals

    return decimals


def get_token_symbol(token_contract, weth_to_eth=True):
    if isinstance(token_contract, str):
        # TODO: load at a specific block?
        token_contract = load_contract(token_contract)

    if token_contract.address in _cache_symbols:
        return _cache_symbols[token_contract.address]

    if token_contract in [brownie.ETH_ADDRESS, brownie.ZERO_ADDRESS]:
        symbol = "ETH"
    elif token_contract.address == "0x57Ab1E02fEE23774580C119740129eAC7081e9D3":
        # old sUSD contract
        symbol = "sUSD"
    elif token_contract.address == "0xC011A72400E58ecD99Ee497CF89E3775d4bd732F":
        # this is a proxy to a proxy to a gnosis safe
        symbol = "SNX"
    elif token_contract.address == "0x88ACDd2a6425c3FaAE4Bc9650Fd7E27e0Bebb7aB":
        # they use unicode for their symbol. i'd rather not deal with that
        symbol = "MIST"
    elif token_contract.address == "0x000000000000C1CB11D5c062901F32D06248CE48":
        symbol = "LGT"
    elif token_contract.address == "0xeb8928eE92EFb06C44d072a24C2BCB993B61e543":
        symbol = "PTUNI-V2-POOL-ETH"
    else:
        if hasattr(token_contract, "symbol"):
            symbol_fn = token_contract.symbol
        elif hasattr(token_contract, "SYMBOL"):
            symbol_fn = token_contract.SYMBOL
        else:
            raise ValueError(token_contract)

        if hasattr(symbol_fn, "call"):
            # some contracts forgot to add "view" to their functions and so we need to call
            # TODO: maybe we should patch brownie to add the "call" function to call-only functions
            symbol = symbol_fn.call()
        else:
            symbol = symbol_fn()

        if not isinstance(symbol, str):
            # Maker (and probably others) return a bytes32 instead of a string!
            # SAI returns b'DAI\x00\x00...'! we are fine with that though since the rename just causes confusion
            # TODO: do we want to make sure SAI is named SAI?
            symbol = symbol.capitalize().rstrip(b"\x00").decode("utf-8")

            if symbol in ["Mkr", "Dai"]:
                # Really? Why don't they capitalize the whole thing?
                symbol = symbol.upper()

    if symbol == "WETH":
        if weth_to_eth:
            symbol = "ETH"
    elif symbol == "WBNB":
        if weth_to_eth:
            symbol = "BNB"
    elif symbol == "UNI-V2":
        token0 = load_contract(token_contract.token0())
        token1 = load_contract(token_contract.token1())

        symbol0 = get_token_symbol(token0, weth_to_eth=True)
        symbol1 = get_token_symbol(token1, weth_to_eth=True)

        # TODO: do this for UNI-V1, BPT, etc.
        symbol = f"UNI-V2-{symbol0}-{symbol1}"
    elif symbol == "BPT":
        underlying_tokens = token_contract.getCurrentTokens()

        underlying_symbols = [
            get_token_symbol(load_contract(underlying), weth_to_eth=True)
            for underlying in underlying_tokens
        ]

        underlying_symbols = "-".join(underlying_symbols)

        symbol = f"BPT-{underlying_symbols}"
    elif symbol.upper() == "UNI-V1":
        underlying_token = load_contract(token_contract.tokenAddress())

        underlying_symbol = get_token_symbol(underlying_token, weth_to_eth=False)

        symbol = f"UNI-V1-{underlying_symbol}"
    elif symbol == "Cake-LP":
        token0 = load_contract(token_contract.token0())
        token1 = load_contract(token_contract.token1())

        symbol0 = get_token_symbol(token0, weth_to_eth=True)
        symbol1 = get_token_symbol(token1, weth_to_eth=True)

        # TODO: do this for UNI-V1, BPT, etc.
        symbol = f"Cake-LP-{symbol0}-{symbol1}"
    elif symbol == "bUNI-V2":
        uni_lp = load_contract(token_contract.token())

        uni_lp_symbol = get_token_symbol(uni_lp)

        symbol = f"b{uni_lp_symbol}"
    elif symbol == "pUNI-V2":
        uni_lp = load_contract(token_contract.token())

        uni_lp_symbol = get_token_symbol(uni_lp)

        symbol = f"p{uni_lp_symbol}"
    elif symbol == "SLP":
        token0 = load_contract(token_contract.token0())
        token1 = load_contract(token_contract.token1())

        symbol0 = get_token_symbol(token0, weth_to_eth=weth_to_eth)
        symbol1 = get_token_symbol(token1, weth_to_eth=weth_to_eth)

        symbol = f"SLP-{symbol0}-{symbol1}"
    elif symbol == "pSLP":
        # pickling SLP
        underlying = load_contract(token_contract.token())

        underlying_symbol = get_token_symbol(underlying, weth_to_eth=weth_to_eth)

        symbol = f"p{underlying_symbol}"
    elif symbol == "BPT":
        underlying_tokens = token_contract.getCurrentTokens()

        underlying_symbols = [
            get_token_symbol(load_contract(underlying), weth_to_eth=weth_to_eth)
            for underlying in underlying_tokens
        ]

        underlying_symbols = " ".join(underlying_symbols)

        symbol = f"BPT {underlying_symbols}"
    elif symbol == "Cake-LP":
        token0 = load_contract(token_contract.token0())
        token1 = load_contract(token_contract.token1())

        symbol0 = get_token_symbol(token0, weth_to_eth=weth_to_eth)
        symbol1 = get_token_symbol(token1, weth_to_eth=weth_to_eth)

        symbol = f"Cake-LP-{symbol0}-{symbol1}"
    elif symbol == "bUNI-V2":
        underlying = load_contract(token_contract.token())

        symbol = get_token_symbol(underlying, weth_to_eth=weth_to_eth)

        symbol = f"b{symbol}"
    elif symbol == "pUNI-V2":
        underlying = load_contract(token_contract.token())

        symbol = get_token_symbol(underlying, weth_to_eth=weth_to_eth)

        symbol = f"p{symbol}"

    _cache_symbols[token_contract.address] = symbol

    return symbol


def print_token_balances(balances, label=None, as_usd=False):
    if label:
        print(label)

    dict_for_printing = dict()

    for token, amount in balances.items():
        decimal_shift = get_decimal_shift(token)
        symbol = get_token_symbol(token, weth_to_eth=False)

        if as_usd:
            raise NotImplementedError("WIP")
        else:
            display_amount = Decimal(amount) / decimal_shift

        if symbol:
            dict_for_printing[symbol] = display_amount
        else:
            dict_for_printing[token.address] = display_amount

    pprint(dict_for_printing)


def safe_token_approve(
    account, balances, spender, extra_balances=None, amount=2 ** 256 - 1, reset=False
):
    """For every token that we have a balance of, Approve unlimited (or a specified amount) for the spender."""
    if extra_balances is None:
        extra_balances = {}

    for token, balance in balances.items():
        token_symbol = get_token_symbol(token, weth_to_eth=False)

        summed_balance = balance + extra_balances.get(token.address, 0)

        if summed_balance == 0:
            continue

        if amount is None:
            # if amount is not specified, we approve the balance
            amount = summed_balance

        # TODO: double check this. my last automated run did an approve, but everything should have already been done
        allowed = token.allowance(account, spender)

        # TODO: include decimals here
        # print(f"{spender} is currently allowed to spend {allowed} of {account}'s {token_symbol}. Need {summed_balance}")

        if allowed >= summed_balance:
            # print(f"No change in approvals needed for {token.address}")
            continue
        elif allowed == 0:
            pass
        elif reset:
            # TODO: we should have a list of tokens that need this behavior instead of taking a kwarg
            print(f"Clearing {token_symbol} ({token.address}) approval...")
            # gas estimators get confused if we don't wait for confirmation here
            token.approve(
                spender, 0, {"from": account, "required_confs": 1, "gas_buffer": 1.3}
            )

        if amount == 2 ** 256 - 1:
            # the amount is the max
            print(f"Approving {spender} for unlimited of {account}'s {token_symbol}...")
        else:
            # the amount was specified
            print(f"Approving {spender} for {amount} of {account}'s {token_symbol}...")

        token.approve(
            spender, amount, {"from": account, "required_confs": 0, "gas_buffer": 1.3}
        )

        # TODO: if debug, print this
        # approve_tx.info()

    brownie.history.wait()
    # TODO: what if one of them reverted?


def transfer_token(from_address, to, token, decimal_amount):
    """Transfer tokens from an account that we don't actually control."""
    token = load_token_or_contract(token)

    decimals = get_token_decimals(token)

    amount = int(decimal_amount * 10 ** decimals)

    token.transfer(to, amount, {"from": from_address})


@contextlib.contextmanager
def print_start_and_end_balance(account, tokens=None):
    initial_gas = account.gas_used
    starting_balance = account.balance()

    print("\nbalance of", account, ":", starting_balance / 1e18)
    print()

    if tokens:
        print("TODO: print starting token balances")

    yield

    gas_used = account.gas_used - initial_gas
    ending_balance = account.balance()

    # TODO: print the number of transactions done?
    print(f"\n{account} used {gas_used:,} gas.")
    print(
        f"\nspent balance of {account}:",
        (starting_balance - ending_balance) / 1e18,
        "\n",
    )

    if tokens:
        print("TODO: print ending token balances")


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
