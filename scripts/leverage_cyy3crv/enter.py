import brownie
import os
import threading
import multiprocessing
from collections import namedtuple
from concurrent.futures import as_completed, ThreadPoolExecutor
from dotenv import load_dotenv, find_dotenv
from lazy_load import lazy
from pprint import pprint

def _load_contract(address):
    if address.lower() == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48":
        # USDC does weird things to get their implementation
        # TODO: don't hard code this
        contract = brownie.Contract.from_explorer(address, as_proxy_for="0xB7277a6e95992041568D9391D09d0122023778A2")
    else:    
        contract = brownie.Contract(address)
        
        if hasattr(contract, 'implementation'):
            impl = contract.implementation.call()
            contract = brownie.Contract.from_explorer(address, as_proxy_for=impl)

    return contract


def _lazy_contract(address):
    return lazy(lambda: _load_contract(address))


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


EnterData = namedtuple("EnterData", [
    "dai",
    "usdc",
    "usdt",
    "threecrv",
    "tip_3crv",
    "y3crv",
    "tip_address",
    "claim_3crv",
])

EnterLoanData = namedtuple("EnterLoanData", [
    "min_3crv_mint_amount",
])


def get_claimable_3crv(account, fee_distribution, min_crv=50):
    claimable = fee_distribution.claim.call(account)

    if claimable < min_crv:
        return 0
    
    return claimable


def get_balances(account, tokens):
    return {token: token.balanceOf(account) for token in tokens}


def infinite_approvals(account, balances, EnterCYY3CRV, claimable_3crv):
    max_approval = 2 ** 256

    for token, balance in balances.items():
        symbol = token.symbol()

        if symbol == '3Crv':
            balance += claimable_3crv

        if balance == 0:
            continue

        allowed = token.allowance(account, EnterCYY3CRV)

        if allowed >= max_approval:
            print(f"No approval needed for {token.address}")
            # TODO: claiming 3crv could increase our balance and mean that we actually do need an approval
            continue
        elif allowed == 0:
            pass
        else:
            # TODO: do any of our tokens actually need this stupid check?
            print(f"Clearing {token.address} approval...")
            allowed = token.approve(EnterCYY3CRV, 0, {"from": account})

        # TODO: unlimited approval?
        print(f"Approving {balance} {token.address}...")
        token.approve(EnterCYY3CRV, balance, {"from": account})


def unlocked_transfer(to, token, amount=10000, unlocked="0x85b931A32a0725Be14285B66f1a22178c672d69B"):
    """Transfer tokens from an account that we don't actually control."""
    decimals = token.decimals()

    amount *= 10 ** decimals

    unlocked = brownie.accounts.at(unlocked, force=True)

    token.transfer(to, amount, {"from": unlocked})


def main():
    load_dotenv(find_dotenv())

    # TODO: what should this be?
    min_3crv_to_claim = 50

    # TODO: we need an account with private keys
    # account = os.environ['LEVERAGE_ACCOUNT']
    # account = brownie.accounts[0]
    account = brownie.accounts.at("5668e.eth", force=True)

    # TODO: use LGT deployer to create these with deterministic addresses
    clone_factory = account.deploy(brownie.ImmutablyOwnedCloneFactory)
    enter_cyy3crv_master = account.deploy(brownie.EnterCYY3CRV)

    salt = ""

    cloneAddress, cloneExists = clone_factory.cloneExists(enter_cyy3crv_master, salt, account)
    if not cloneExists:
        print("Creating your clone of EnterCYY3CRV...")
        newCloneAddress = clone_factory.clone(enter_cyy3crv_master, salt, account, {"from": account}).return_value
        assert cloneAddress == newCloneAddress, "bad address"

        cloneAddress = newCloneAddress

    EnterCYY3CRV = brownie.EnterCYY3CRV.at(cloneAddress)

    cloneOwner = EnterCYY3CRV.owner()

    # assert cloneOwner == account, "Wrong owner detected!"

    print("Preparing contracts...")
    dai = _lazy_contract(EnterCYY3CRV.DAI())
    usdc = _lazy_contract(EnterCYY3CRV.USDC())
    usdt = _lazy_contract(EnterCYY3CRV.USDT())
    threecrv = _lazy_contract(EnterCYY3CRV.THREE_CRV())
    threecrv_pool = _lazy_contract(EnterCYY3CRV.THREE_CRV_POOL())
    y3crv = _lazy_contract(EnterCYY3CRV.Y_THREE_CRV())
    cyy3crv = _lazy_contract(EnterCYY3CRV.CY_Y_THREE_CRV())
    fee_distribution = _lazy_contract(EnterCYY3CRV.THREE_CRV_FEE_DISTRIBUTION())
 
    # use multiple workers to fetch the contracts
    # there will still be some to fetch, but this speeds things up some
    # this can take some time since solc/vyper may have to download
    poke_contracts([dai, usdc, usdt, threecrv, threecrv_pool, y3crv, cyy3crv, fee_distribution])

    print(f"DEBUG MODE! giving some tokens to {account}...")
    # TODO: only do this in dev mode
    unlocked_transfer(account, dai)
    # TODO: why did usdt revert?
    # unlocked_transfer(account, usdt)

    tokens = [dai, usdc, usdt, threecrv, y3crv, cyy3crv]

    balances = get_balances(account, tokens)
    print(f"{account} balances")
    pprint(balances)

    claimable_3crv = get_claimable_3crv(account, fee_distribution, min_3crv_to_claim)

    # TODO: calculate these
    min_3crv_mint_amount = 1
    tip_3crv = 1
    tip_address = brownie.accounts[1]

    enter_data = EnterData(
        dai=balances[dai],
        usdc=balances[usdc],
        usdt=balances[usdt],
        threecrv=balances[threecrv],
        tip_3crv=tip_3crv,
        y3crv=balances[y3crv],
        tip_address=tip_address,
        claim_3crv=claimable_3crv > min_3crv_to_claim,
    )

    enter_loan_data = EnterLoanData(
        min_3crv_mint_amount=min_3crv_mint_amount,
    )

    pprint(enter_data)
    pprint(enter_loan_data)

    # TODO: what min amount? these aren't all the same units, but i think thats okay here since its just a quick check for non-zero
    summed_balances = enter_data.dai + enter_data.usdc + enter_data.usdt + enter_data.threecrv + enter_data.y3crv + claimable_3crv

    assert summed_balances > 100, "no coins"

    infinite_approvals(account, balances, EnterCYY3CRV, claimable_3crv)

    enter_tx = EnterCYY3CRV.enter(enter_data, enter_loan_data, {"from": account})

    print("success!")
    enter_tx.info()

    print("EnterCYY3CRV balances")
    pprint(get_balances(EnterCYY3CRV, tokens))

    print("account balances")
    pprint(get_balances(account, tokens))
