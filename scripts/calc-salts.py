# UNDER CONSTRUCTION
# TODO: https://github.com/johguse/ERADICATE2/issues/5
# TODO: PR for ERADICATE2 to exit once an address with a sufficient score is found?
# Calculate salts for use with CREATE2.
# This can be used to create addresses with lots of zeros which are slightly cheaper to call.
# This can also be used for creating vanity addresses with fun patterns.
from argobytes_util import *
from brownie import *
from eth_utils import keccak, to_checksum_address, to_bytes
import os
import rlp


def main():
    """Calculate the salts for deploying the diamond."""
    deployer = os.environ.get("DEPLOYER", None)
    if deployer is None:
        deployer = accounts[0]
    else:
        deployer = Account.at(deployer)

    print("Deploying DiamondCreator from", deployer)

    # when using CREATE, contract addresses are determined by the nonce
    # IMPORTANT! after running this script, don't send any other transactions from this account or your salt won't be valid!
    diamond_creator_address = mk_contract_address(deployer.address, deployer.nonce)

    # initcode is deployment bytecode + constructor params
    # lots of people using different terms here, but i think calling this "initcode" makes the most sense
    #
    # cutter
    #
    # TODO: cutter and loupe salts can be searched in parallel
    cutter_initcode = DiamondCutter.deploy.encode_input()

    print("Cutter: ERADICATE2 -A", diamond_creator_address, "-I", cutter_initcode, "--zero-bytes")

    input("\nPress [enter] to continue")

    cutter_salt = input("Cutter salt:")
    cutter_expected_address = input("Cutter address:")

    # TODO: count the zero bytes?

    cutter_address = mk_contract_address2(diamond_creator_address, cutter_salt, cutter_initcode)

    print("Calculated cutter address", cutter_address)

    assert(cutter_expected_address == cutter_address)

    #
    # loupe
    #
    loupe_initcode = DiamondLoupe.deploy.encode_input()

    print("Loupe: ERADICATE2 -A", diamond_creator_address, "-I", loupe_initcode, "--zero-bytes")

    input("\nPress [enter] to continue")

    loupe_salt = input("Loupe salt:")
    loupe_expected_address = input("Loupe address:")

    # TODO: count the zero bytes?

    loupe_address = mk_contract_address2(diamond_creator_address, loupe_salt, loupe_initcode)

    print("Calculated loupe address", loupe_address)

    assert(loupe_expected_address == loupe_address)

    #
    # diamond
    #

    diamond_initcode = Diamond.deploy.encode_input(cutter_address, loupe_address)

    print("ERADICATE2 -A", diamond_creator_address, "-I", loupe_initcode, "--zero-bytes")

    input("\nPress [enter] to continue")

    diamond_salt = input("Diamond salt:")
    diamond_expected_address = input("Diamond address:")

    # TODO: count the zero bytes?

    diamond_address = mk_contract_address2(diamond_creator_address, diamond_salt, diamond_initcode)

    print("Calculated diamond_address", diamond_address)

    assert(diamond_expected_address == diamond_address)

    # TODO: now what?
    # all the rest of the contracts can be searched in parallel
    assert False


def calculate_one_salt():
    """We don't want to always generate all the salts except on first deploy. Later deploys just need one contract."""
    # TODO: think about this more

    # first, we need to prompt what address is doing the deploy
    # if this is an EOA,
    #     tell them to run calc-salts.py:main instead

    # then we use ERADICATE2 to find a salt that gives all the other contract addresses lots of zeros when deployed from ArgobytesOwnedVault
    assert False

    loupe_address = mk_contract_address2(diamond_creator_address, loupe_salt, loupe_initcode)
