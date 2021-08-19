# UNDER CONSTRUCTION
# TODO: https://github.com/johguse/ERADICATE2/issues/5
# TODO: PR for ERADICATE2 to exit once an address with a sufficient score is found?
# Calculate salts for use with CREATE2.
# This can be used to create addresses with lots of zeros which are slightly cheaper to call.
# This can also be used for creating vanity addresses with fun patterns.
# TODO: rewrite this now that we aren't using diamonds
import os

from argobytes_mainnet import *
from argobytes_util import *
from brownie import *


def main():
    """Calculate the salts for deploying the contracts."""
    deployer = os.environ.get("DEPLOYER", None)
    if deployer is None:
        deployer = accounts[0]
    else:
        deployer = Account.at(deployer)

    #
    # ArgobytesFactory19
    #
    print("Deploying ArgobytesFactory19 via", LiquidGasTokenAddress, "as", deployer)

    # initcode is deployment bytecode + constructor params
    # lots of people using different terms here, but i think calling this "initcode" makes the most sense
    proxy_factory_initcode = ArgobytesFactory.deploy.encode_input()

    print(
        "Cutter: ERADICATE2 -A",
        LiquidGasTokenAddress,
        "-I",
        proxy_factory_initcode,
        "--zero-bytes",
    )

    input("\nPress [enter] to continue")

    proxy_factory_salt = input("ArgobytesFactory salt: ")
    proxy_factory_expected_address = input("ArgobytesFactory address: ")

    # TODO: count the zero bytes?

    proxy_factory_address, proxy_factory_salt = mk_contract_address2(
        LiquidGasTokenAddress,
        proxy_factory_initcode,
        salt=proxy_factory_salt,
    )

    print("Calculated ArgobytesFactory address:", proxy_factory_address, "\n")

    assert proxy_factory_expected_address == proxy_factory_address.lower()

    # TODO: deploy the rest

    print("now what?")
    assert False


def calculate_one_salt():
    """We don't want to always generate all the salts except on first deploy. Later deploys just need one contract."""
    # TODO: think about this more

    # first, we need to prompt what address is doing the deploy
    # if this is an EOA,
    #     tell them to run calc-salts.py:main instead

    # then we use ERADICATE2 to find a salt that gives all the other contract addresses lots of zeros when deployed from ArgobytesOwnedVault
    assert False

    mk_contract_address2(argobytes_factory, loupe_initcode, salt=loupe_salt)
