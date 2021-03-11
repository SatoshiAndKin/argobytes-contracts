import os
import multiprocessing
import rlp

from brownie import accounts, Contract, web3, ZERO_ADDRESS
from brownie.exceptions import VirtualMachineError
from copy import copy
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from eth_abi.packed import encode_abi_packed
from eth_utils import keccak, to_checksum_address, to_bytes, to_hex
from lazy_load import lazy


ActionTuple = namedtuple("Action", [
    "target",
    "call_type",
    "forward_value",
    "data",
])


class Action():

    def __init__(self, contract, call_type: str, forward_value: bool, function_name: str, *function_args):
        # TODO: use an enum
        if call_type == "delegate":
            call_int = 0
        elif call_type == "call":
            call_int = 1
        elif call_type == "admin":
            call_int = 2
        else:
            raise NotImplementedError         

        data = getattr(contract, function_name).encode_input(*function_args)

        self.tuple = ActionTuple(contract.address, call_int, forward_value, data)


def approve(account, balances, extra_balances, spender, amount=2**256-1):
    for token, balance in balances.items():
        if token.address in extra_balances:
            balance += extra[token.address]

        if balance == 0:
            continue

        allowed = token.allowance(account, spender)

        if allowed >= amount:
            print(f"No approval needed for {token.address}")
            # TODO: claiming 3crv could increase our balance and mean that we actually do need an approval
            continue
        elif allowed == 0:
            pass
        else:
            # TODO: do any of our tokens actually need this stupid check?
            print(f"Clearing {token.address} approval...")
            allowed = token.approve(spender, 0, {"from": account})

        if amount is None:
            print(f"Approving {spender} for {balance} {token.address}...")
            amount = balance
        else:
            print(f"Approving {spender} for unlimited {token.address}...")

        token.approve(spender, amount, {"from": account})


def get_balances(account, tokens):
    return {token: token.balanceOf(account) for token in tokens}


def get_or_clone(owner, argobytes_factory, deployed_contract, salt=""):
    clone_exists, clone_address = argobytes_factory.cloneExists(deployed_contract, salt, owner)

    if not clone_exists:
        clone_address = argobytes_factory.createClone(deployed_contract, salt).return_value

    return Contract.from_abi(deployed_contract._name, clone_address, deployed_contract.abi, owner)


def get_or_create(default_account, contract, salt="", constructor_args=[]):
    """Use eip-2470 to create a contract with deterministic addresses."""
    contract_initcode = contract.deploy.encode_input(*constructor_args)

    print(f"salt: '{salt}'")
    print(f"contract_initcode: '{contract_initcode}'")

    contract_address = mk_contract_address2(SingletonFactory.address, salt, contract_initcode)

    if web3.eth.getCode(contract_address).hex() == "0x":
        tx = SingletonFactory.deploy(contract_initcode, salt, {"from": default_account})

        deployed_contract_address = tx.return_value

        assert contract_address == deployed_contract_address, f"something is wrong in the address calculation. {contract_address} != {deployed_contract_address}"

        contract_address = deployed_contract_address

    return contract.at(contract_address, default_account)


def lazy_contract(address: str):
    return lazy(lambda: load_contract(address))


def load_contract(address):
    if address.lower() == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48":
        # USDC does weird things to get their implementation
        # TODO: don't hard code this
        contract = Contract("0xB7277a6e95992041568D9391D09d0122023778A2")
        contract.address = address
    else:    
        contract = Contract(address)
        
        if hasattr(contract, 'implementation'):
            contract = Contract(contract.implementation.call())
            contract.address = address

        if hasattr(contract, 'target'):
            contract = Contract(contract.target.call())
            contract.address = address

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

    keccak256 (0xff ++ sender ++ salt ++ keccak256 (init_code)) [12:]

    # TODO: this is not correct
    """
    raw = b"".join([
        to_bytes(hexstr="0xff"),
        to_bytes(hexstr=sender),
        to_bytes(hexstr=salt),
        keccak(to_bytes(hexstr=initcode)),
    ])

    address_bytes = keccak(raw)[-20:]

    return to_checksum_address(address_bytes)


def poke_contracts(contracts):
    # we don't want to query etherscan's API too quickly
    # they limit everyone to 5 requests/second
    # if the contract hasn't been fetched, getting it will take longer than a second
    # if the contract has been already fetched, we won't hit their API
    max_workers = min(multiprocessing.cpu_count(), 5)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        def poke_contract(contract):
            _ = contract.address

        fs = [executor.submit(poke_contract, contract) for contract in contracts]

        for _f in as_completed(fs):
            # we could check errors here and log, but the user will see those errors if they actually use a broken contract
            # and if they aren't using hte contract, there's no reason to bother them with warnings
            pass


def reset_block_time(synthetix_depot_action):
    # synthetix_address_resolver = interface.IAddressResolver(SynthetixAddressResolver)

    # TODO: get this from the address resolver instead
    synthetix_exchange_rates = Contract("0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77")

    token_bytestr = to_hex32(text="ETH")

    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time: ", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    # TODO: unstead of last update time we just went back 10 years
    web3.testing.mine(last_update_time)


def to_hex32(primitive=None, hexstr=None, text=None):
    return to_hex(primitive, hexstr, text).ljust(66, '0')


def transfer_token(from_address, to, token, amount):
    """Transfer tokens from an account that we don't actually control."""
    decimals = token.decimals()

    amount *= 10 ** decimals

    token.transfer(to, amount, {"from": from_address})


# TODO: move this to argobytes_mainnet. then rename it to mainnet_contracts
# eip-2470
SingletonFactory = lazy_contract("0xce0042B868300000d44A59004Da54A005ffdcf9f")

# dydx wrapper https://github.com/albertocuestacanada/ERC3156-Wrappers
DyDxFlashLender = lazy_contract("0x6bdC1FCB2F13d1bA9D26ccEc3983d5D4bf318693")
