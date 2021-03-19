"""Handle Ethereum smart Contracts."""
import multiprocessing
from concurrent.futures import as_completed, ThreadPoolExecutor
from warnings import warn

import brownie
import rlp
from brownie import Contract, ETH_ADDRESS, project, web3, ZERO_ADDRESS
from lazy_load import lazy
from eth_utils import to_bytes, keccak, to_checksum_address

from argobytes import to_hex32


def get_deterministic_contract(default_account, contract, salt="", constructor_args=None):
    """Use eip-2470 to create a contract with deterministic addresses."""
    if constructor_args is None:
        constructor_args = []

    contract_initcode = contract.deploy.encode_input(*constructor_args)

    contract_address = mk_contract_address2(
        SingletonFactory.address, salt, contract_initcode
    )

    if web3.eth.getCode(contract_address).hex() == "0x":
        raise ValueError(f"Contract {contract.name} not deployed!")

    return contract.at(contract_address, default_account)


def get_or_clone(owner, argobytes_factory, deployed_contract, salt=""):
    clone_exists, clone_address = argobytes_factory.cloneExists(
        deployed_contract, salt, owner
    )

    if not clone_exists:
        clone_address = argobytes_factory.createClone(
            deployed_contract, salt
        ).return_value

    return Contract.from_abi(
        deployed_contract._name, clone_address, deployed_contract.abi, owner
    )


def get_or_clones(owner, argobytes_factory, deployed_contract, salts):
    needed_salts = []
    my_proxys_proxies = []

    for salt in salts:
        (proxy_exists, proxy_address) = argobytes_factory.cloneExists(deployed_contract, salt, owner)

        my_proxys_proxies.append(proxy_address)

        if not proxy_exists:
            # print("Salt", salt, "will deploy at", proxy_address)
            needed_salts.append(salt)

    if needed_salts:
        # deploy more proxies that are all owned by the first
        if len(needed_salts) == 1:
            sybil_tx = argobytes_factory.createClone(
                deployed_contract,
                needed_salts[0],
                owner,
            )
        else:
            sybil_tx = argobytes_factory.createClones(
                deployed_contract,
                needed_salts,
                owner,
            )

        sybil_tx.info()

        # we already calculated the address above. just use that
        # my_proxys_proxies.extend([event['clone'] for event in sybil_tx.events["NewClone"]])

    _contract = lambda address: Contract.from_abi(
        deployed_contract._name, address, deployed_contract.abi, owner
    )

    return [_contract(address) for address in my_proxys_proxies]


# TODO: rename to get_or_deterministic_create?
# @functools.lru_cache(maxsize=None)
def get_or_create(default_account, contract, salt="", constructor_args=None):
    """Use eip-2470 to create a contract with deterministic addresses."""
    if constructor_args is None:
        constructor_args = []

    contract_initcode = contract.deploy.encode_input(*constructor_args)

    contract_address = mk_contract_address2(
        SingletonFactory.address, salt, contract_initcode
    )

    if web3.eth.getCode(contract_address).hex() == "0x":
        tx = SingletonFactory.deploy(contract_initcode, salt, {"from": default_account})

        deployed_contract_address = tx.return_value

        assert (
            contract_address == deployed_contract_address
        ), f"create2 error: {contract_address} != {deployed_contract_address}"

        contract_address = deployed_contract_address

    print(f"Created {contract._name} at {contract_address}\n")

    return contract.at(contract_address, default_account)


def get_or_create_factory(default_account, salt):
    return get_or_create(
        default_account,
        project.ArgobytesContractsProject.ArgobytesFactory,
        salt,
        None
    )


def get_or_create_proxy(default_account, salt):
    return get_or_create(
        default_account,
        project.ArgobytesContractsProject.ArgobytesProxy,
        salt,
        None
    )


def get_or_create_flash_borrower(default_account, salt):
    return get_or_create(
        default_account,
        project.ArgobytesContractsProject.ArgobytesFlashBorrower,
        salt,
        None
    )


def lazy_contract(address: str):
    return lazy(lambda: load_contract(address))


# @functools.lru_cache(maxsize=None)
def load_contract(token_name_or_address: str):
    if token_name_or_address.lower() == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48":
        # USDC does weird things to get their implementation
        # TODO: don't hard code this!!!
        impl = Contract("0xB7277a6e95992041568D9391D09d0122023778A2")

        proxy = Contract("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")

        contract = Contract.from_abi(proxy._name, proxy.address, impl.abi)

        return contract

    if token_name_or_address.lower() in ["eth", ZERO_ADDRESS, ETH_ADDRESS.lower()]:
        # just use weth for eth
        token_name_or_address = "weth"
    elif token_name_or_address.lower() == "ankreth":
        # TODO: find a tokenlist with this on it
        token_name_or_address = "0xe95a203b1a91a908f9b9ce46459d101078c2c3cb"
    elif token_name_or_address.lower() == "obtc":  # boring DAO btc
        # TODO: find a tokenlist with this on it
        token_name_or_address = "0x8064d9Ae6cDf087b1bcd5BDf3531bD5d8C537a68"

    # TODO: i think we have to import this late because it is created by `connect` or something
    from brownie.network.web3 import _resolve_address

    # this raises a ValueError if this is not an address or ENS name
    address = _resolve_address(token_name_or_address)

    contract = Contract(address)

    # TODO: we shouldn't need from_explorer, but i'm seeing weird things were DAI loads as IWETH9
    if contract._name == "IWETH9" and address != "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2":
        warn(f"Reloading contract supposedly named IWETH9: {address}")
        contract = Contract.from_explorer(address)

    # check if this is a proxy contract
    # TODO: theres other ways to have an impl too. usdc has one that uses storage
    impl = None
    if hasattr(contract, "implementation"):
        impl = Contract(contract.implementation.call())
    elif hasattr(contract, "target"):
        impl = Contract(contract.target.call())

    if impl:
        contract = Contract.from_abi(contract._name, address, impl.abi)

    return contract


def mk_contract_address(sender: str, nonce: int) -> str:
    """Create a contract address.

    https://ethereum.stackexchange.com/a/761/620
    """
    sender_bytes = to_bytes(hexstr=sender)
    raw = rlp.encode([sender_bytes, nonce])
    h = keccak(raw)
    address_bytes = h[-20:]
    return to_checksum_address(address_bytes)


def mk_contract_address2(sender: str, salt: str, initcode: str) -> str:
    """Create2 a contract address.

    keccak256 (0xff ++ sender ++ salt ++ keccak256 (init_code)) [-20:]

    # TODO: this is not correct
    """
    if not salt.startswith("0x"):
        salt = to_hex32(text=salt)

    raw = b"".join(
        [
            to_bytes(hexstr="0xff"),
            to_bytes(hexstr=sender),
            to_bytes(hexstr=salt),
            keccak(to_bytes(hexstr=initcode)),
        ]
    )

    assert len(raw) == 85, "incorrect length of inputs!"

    address_bytes = keccak(raw)[-20:]

    return to_checksum_address(address_bytes)


def poke_contracts(contracts):
    # TODO: this might be causing things to load wrong. investigate more
    # we don't want to query etherscan's API too quickly
    # they limit everyone to 5 requests/second
    # if the contract hasn't been fetched, getting it will take longer than a second
    # if the contract has been already fetched, we won't hit their API
    max_workers = min(multiprocessing.cpu_count(), 5)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:

        def poke_contract(contract):
            _ = contract.address

        futures = [executor.submit(poke_contract, contract) for contract in contracts]

        for _f in as_completed(futures):
            # we could check errors here and log, but the user will see those errors if they actually use a broken contract
            # and if they aren't using hte contract, there's no reason to bother them with warnings
            pass


# eip-2470
SingletonFactory = lazy_contract("0xce0042B868300000d44A59004Da54A005ffdcf9f")

# dydx wrapper https://github.com/albertocuestacanada/ERC3156-Wrappers
DyDxFlashLender = lazy_contract("0x6bdC1FCB2F13d1bA9D26ccEc3983d5D4bf318693")

OneSplit = lazy_contract("1proto.eth")
# USDC may not be decentralized, but Coinbase can trade to USD in my bank account at 1:1 and no fee
USDC = lazy_contract("usdc")

# lazy load these because they aren't available at import time here
# TODO: use long project path in case multiple projects are loaded?
ArgobytesAuthority = lazy(lambda: brownie.ArgobytesAuthority)
ArgobytesFactory = lazy(lambda: brownie.ArgobytesFactory)
ArgobytesMulticall = lazy(lambda: brownie.ArgobytesMulticall)

# clonable
ArgobytesFlashBorrower = lazy(lambda: brownie.ArgobytesFlashBorrower)
ArgobytesProxy = lazy(lambda: brownie.ArgobytesProxy)

# actions
ArgobytesTrader = lazy(lambda: brownie.ArgobytesTrader)
EnterCYY3CRVAction = lazy(lambda: brownie.EnterCYY3CRVAction)
ExitCYY3CRVAction = lazy(lambda: brownie.ExitCYY3CRVAction)

# exchanges
CurveFiAction = lazy(lambda: brownie.CurveFiAction)
ExampleAction = lazy(lambda: brownie.ExampleAction)
KyberAction = lazy(lambda: brownie.KyberAction)
UniswapV1Action = lazy(lambda: brownie.UniswapV1Action)
UniswapV2Action = lazy(lambda: brownie.UniswapV2Action)
Weth9Action = lazy(lambda: brownie.Weth9Action)
