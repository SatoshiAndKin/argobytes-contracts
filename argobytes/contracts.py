"""Handle Ethereum smart Contracts."""
import multiprocessing
from collections import namedtuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from enum import IntFlag
from warnings import warn

import brownie
import click
import rlp
from brownie import ETH_ADDRESS, ZERO_ADDRESS, Contract, web3
from brownie.network import web3
from eth_abi import decode_single
from eth_utils import keccak, to_bytes, to_checksum_address
from lazy_load import lazy

from argobytes.web3_helpers import to_hex32

ActionTuple = namedtuple(
    "Action",
    [
        "target",
        "call_type",
        "forward_value",
        "data",
    ],
)


class ArgobytesActionCallType(IntFlag):
    DELEGATE = 0
    CALL = 1
    ADMIN = 2


class ArgobytesAction:
    def __init__(
        self,
        contract,
        call_type: ArgobytesActionCallType,
        forward_value: bool,
        function_name: str,
        *function_args,
    ):
        data = getattr(contract, function_name).encode_input(*function_args)

        self.tuple = ActionTuple(contract.address, call_type, forward_value, data)


class EthContract:
    def __init__(self):
        """Handle ETH like an ERC20."""
        self.address = brownie.ETH_ADDRESS

    def decimals(self):
        return 18

    def symbol(self):
        return "ETH"

    def balanceOf(self, account):
        return brownie.web3.eth.getBalance(str(account))


def get_deterministic_contract(default_account, contract, salt="", constructor_args=None):
    """Use eip-2470 to create a contract with deterministic addresses."""
    if constructor_args is None:
        constructor_args = []

    contract_initcode = contract.deploy.encode_input(*constructor_args)

    contract_address = mk_contract_address2(SingletonFactory.address, salt, contract_initcode)

    if web3.eth.getCode(contract_address).hex() == "0x":
        raise ValueError(f"Contract {contract.name} not deployed!")

    return contract.at(contract_address, default_account)


def get_or_clone(owner, argobytes_factory, deployed_contract, salt=""):
    """Fetches an existing clone or creates a new clone."""
    clone_exists, clone_address = argobytes_factory.cloneExists(deployed_contract, salt, owner)

    if not clone_exists:
        clone_address = argobytes_factory.createClone(deployed_contract, salt).return_value

    return Contract.from_abi(deployed_contract._name, clone_address, deployed_contract.abi, owner)


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
            argobytes_factory.createClone(
                deployed_contract,
                needed_salts[0],
                owner,
            )
        else:
            argobytes_factory.createClones(
                deployed_contract,
                needed_salts,
                owner,
            )

        # sybil_tx.info()

        # we already calculated the address above. just use that
        # my_proxys_proxies.extend([event['clone'] for event in sybil_tx.events["NewClone"]])

    _contract = lambda address: Contract.from_abi(deployed_contract._name, address, deployed_contract.abi, owner)

    return [_contract(address) for address in my_proxys_proxies]


def get_or_clone_flash_borrower(account, borrower_salt="", clone_salt="", factory_salt=""):
    raise NotImplementedError(
        "only get_factory and get_flash_borrower. if we create, users might be surprised by a deploy. deploy should always be done via deploy script"
    )
    factory = get_or_create_factory(account, factory_salt)

    # we don't actually want the proxy. flash_borrower does more
    # proxy = get_or_create_proxy(account, salt)
    flash_borrower = get_or_create_flash_borrower(account, borrower_salt)

    clone = get_or_clone(account, factory, flash_borrower, clone_salt)

    print(f"clone owned by {account}:", clone)

    return (factory, flash_borrower, clone)


# TODO: rename to get_or_deterministic_create?
# @functools.lru_cache(maxsize=None)
def get_or_create(default_account, contract, no_create=False, salt="", constructor_args=None):
    """Use eip-2470 to create a contract with deterministic addresses."""
    if constructor_args is None:
        constructor_args = []

    contract_initcode = contract.deploy.encode_input(*constructor_args)

    contract_address = mk_contract_address2(SingletonFactory.address, salt, contract_initcode)

    if web3.eth.getCode(contract_address).hex() == "0x":
        if no_create:
            raise Exception(f"{contract} is not yet deployed. This is likely an issue with configuration.")
        deploy_tx = SingletonFactory.deploy(contract_initcode, salt, {"from": default_account})

        deployed_contract_address = deploy_tx.return_value

        assert (
            contract_address == deployed_contract_address
        ), f"create2 error: {contract_address} != {deployed_contract_address}"

        contract_address = deployed_contract_address

        print(f"Created {contract._name} at {contract_address}\n")
    else:
        print(f"Found {contract._name} at {contract_address}\n")

    return contract.at(contract_address, default_account)


def get_or_create_factory(default_account, salt):
    return get_or_create(default_account, ArgobytesFactory, salt, None)


def get_or_create_proxy(default_account, salt):
    return get_or_create(default_account, ArgobytesProxy, salt, None)


def get_or_create_flash_borrower(default_account, salt):
    return get_or_create(default_account, ArgobytesFlashBorrower, salt, None)


def lazy_contract(address, owner=None):
    def _owner(owner):
        if owner:
            return owner

        try:
            click_ctx = click.get_current_context()
        except Exception:
            return None

        return click_ctx.obj.get("lazy_contract_default_account", None)

    return lazy(lambda: load_contract(address, _owner(owner)))


def load_contract(token_name_or_address: str, owner=None, block=None, force=False):
    # TODO: cache by block

    if callable(token_name_or_address):
        # sometimes it is useful to get the address from a function
        try:
            token_name_or_address = token_name_or_address()
        except TypeError:
            # this is odd. i've seen `TypeError: 'Contract' object is not callable`
            pass

    if isinstance(token_name_or_address, Contract) or isinstance(token_name_or_address, EthContract):
        # we were given a contract rather than an address or token name. return early
        if owner:
            token_name_or_address._owner = owner
        return token_name_or_address

    if isinstance(token_name_or_address, int):
        token_name_or_address = to_checksum_address(hex(token_name_or_address))

    # TODO: don't lower. use checksum addresses everywhere
    if token_name_or_address.lower() in ["eth", ZERO_ADDRESS, ETH_ADDRESS.lower()]:
        # TODO: just use weth for eth?
        # TODO: we need this to work on other chains like BSC and Matic
        return EthContract()
    elif token_name_or_address.lower() == "ankreth":
        # TODO: find a tokenlist with this on it
        token_name_or_address = to_checksum_address("0xe95a203b1a91a908f9b9ce46459d101078c2c3cb")
    elif token_name_or_address.lower() == "obtc":  # boring DAO BTC
        # TODO: find a tokenlist with this on it
        token_name_or_address = "0x8064d9Ae6cDf087b1bcd5BDf3531bD5d8C537a68"

    # this raises a ValueError if this is not an address or ENS name
    if "." in token_name_or_address:
        if block is not None:
            # TODO: PR against web3 to take a block argument
            # https://github.com/ethereum/web3.py/issues/1984
            warn("Looking up {token_name_or_address} against the latest block, not {block}")
        address = web3.ens.resolve(token_name_or_address)
    else:
        address = to_checksum_address(token_name_or_address)

    if force:
        contract = Contract.from_explorer(address)
        contract._owner = owner
    else:
        contract = Contract(address, owner=owner)

    # check if this is a proxy contract
    contract = check_for_proxy(contract, block, force=force)
    contract._owner = owner

    return contract


def check_for_proxy(contract, block, force=False):
    # if this doesn't look like a proxy, return early

    # TODO: cache on this (include the block in the key!)

    if contract._name == "DSProxy":
        return contract

    if not ("Proxy" in contract._name or hasattr(contract, "implementation") or hasattr(contract, "target")):
        return contract

    impl_addr = brownie.ZERO_ADDRESS

    if impl_addr == brownie.ZERO_ADDRESS and hasattr(contract, "implementation"):
        try:
            # sometimes even if this function exists, it reverts because we are supposed to look at some random storage slot instead
            impl_addr = contract.implementation.call()
        except Exception:
            pass

    if impl_addr == brownie.ZERO_ADDRESS and hasattr(contract, "target"):
        impl_addr = contract.target.call()

    if impl_addr == brownie.ZERO_ADDRESS:
        # maybe its "org.zepplinos.proxy.implementation"
        impl_addr = web3.eth.getStorageAt(
            contract.address,
            "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
            block,
        )
        try:
            impl_addr = decode_single("address", impl_addr)
        except Exception:
            impl_addr = brownie.ZERO_ADDRESS

    if impl_addr == brownie.ZERO_ADDRESS:
        # or maybe its https://eips.ethereum.org/EIPS/eip-1967 Unstructured Storage Proxies
        impl_addr = web3.eth.getStorageAt(
            contract.address,
            "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
            block,
        )
        try:
            impl_addr = decode_single("address", impl_addr)
        except Exception:
            impl_addr = brownie.ZERO_ADDRESS

    if impl_addr == brownie.ZERO_ADDRESS:
        # or maybe they are using EIP-1967 beacon address
        beacon_addr = web3.eth.getStorageAt(
            contract.address,
            "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
            block,
        )
        try:
            beacon_addr = decode_single("address", beacon_addr)
        except Exception:
            pass
        else:
            if beacon_addr != brownie.ZERO_ADDRESS:
                if force:
                    beacon = Contract.from_explorer(beacon_addr)
                else:
                    beacon = Contract(beacon_addr)

                impl_addr = beacon.implementation.call()

    if impl_addr == brownie.ZERO_ADDRESS and contract._name == "Proxy":
        # TODO: this might catch more than we want! lots of contracts use storage slot 0!
        impl_addr = web3.eth.getStorageAt(contract.address, 0, block)
        try:
            impl_addr = decode_single("address", impl_addr)
        except Exception:
            impl_addr = brownie.ZERO_ADDRESS

    if impl_addr == brownie.ZERO_ADDRESS:
        # logger.debug(f"Could not detect implementation contract for {contract}")
        return contract

    if force:
        impl = Contract.from_explorer(impl_addr)
    else:
        impl = Contract(impl_addr)

    # the proxy might be a proxy itself
    impl = check_for_proxy(impl, block, force=force)

    if hasattr(impl, "_full_name"):
        impl_name = impl._full_name
    else:
        impl_name = impl._name

    # create a new contract object with the implementation's abi but the proxy's address
    contract = Contract.from_abi(contract._name, contract.address, impl.abi)

    if contract._name == impl_name or not impl_name:
        full_name = contract._full_name
    else:
        full_name = f"{contract._name} to {impl_name}"

    contract._full_name = full_name
    contract._impl_contract = impl
    return contract


def mk_contract_address(sender: str, nonce: int) -> str:
    """Create a contract address.

    https://ethereum.stackexchange.com/a/761/620
    """
    sender_bytes = to_bytes(hexstr=sender)
    raw = rlp.encode([sender_bytes, nonce])
    hashed = keccak(raw)
    address_bytes = hashed[-20:]
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

ArgobytesProject = lazy(lambda: brownie.project.ArgobytesProject)

ArgobytesInterfaces = lazy(lambda: ArgobytesProject.interface)

# lazy load these because they aren't available at import time here
# TODO: use long project path in case multiple projects are loaded?
ArgobytesAuthority = lazy(lambda: ArgobytesProject.ArgobytesAuthority)
ArgobytesFactory = lazy(lambda: ArgobytesProject.ArgobytesFactory)
ArgobytesMulticall = lazy(lambda: ArgobytesProject.ArgobytesMulticall)

# clonable
ArgobytesFlashBorrower = lazy(lambda: ArgobytesProject.ArgobytesFlashBorrower)
ArgobytesProxy = lazy(lambda: ArgobytesProject.ArgobytesProxy)

# actions
ArgobytesTrader = lazy(lambda: ArgobytesProject.ArgobytesTrader)
EnterCYY3CRVAction = lazy(lambda: ArgobytesProject.EnterCYY3CRVAction)
ExitCYY3CRVAction = lazy(lambda: ArgobytesProject.ExitCYY3CRVAction)

# exchanges
CurveFiAction = lazy(lambda: ArgobytesProject.CurveFiAction)
ExampleAction = lazy(lambda: ArgobytesProject.ExampleAction)
KyberAction = lazy(lambda: ArgobytesProject.KyberAction)
UniswapV1Action = lazy(lambda: ArgobytesProject.UniswapV1Action)
UniswapV2Action = lazy(lambda: ArgobytesProject.UniswapV2Action)
Weth9Action = lazy(lambda: ArgobytesProject.Weth9Action)
