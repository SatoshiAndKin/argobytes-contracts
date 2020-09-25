# UNDER CONSTRUCTION
# TODO: https://github.com/johguse/ERADICATE2/issues/5
# TODO: PR for ERADICATE2 to exit once an address with a sufficient score is found?
# Calculate salts for use with CREATE2.
# This can be used to create addresses with lots of zeros which are slightly cheaper to call.
# This can also be used for creating vanity addresses with fun patterns.
# TODO: rewrite this now that we aren't using diamonds
import rlp
import os
from eth_utils import keccak, to_checksum_address, to_bytes
from brownie import *
from argobytes_util import *


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

    # Cutter salt: 0x42a04a7c2ffd74752fcc360ccf7db1fa445029fcfe98f819d8eaa4c5d7fc2a3f
    # Cutter address: 0xc27e53bb0041689e077600004d88000000356836

    cutter_salt = input("Cutter salt: ")
    cutter_expected_address = input("Cutter address: ")

    # TODO: count the zero bytes?

    cutter_address = mk_contract_address2(diamond_creator_address, cutter_salt, cutter_initcode)

    print("Calculated cutter address:", cutter_address, "\n")

    assert(cutter_expected_address == cutter_address.lower())

    #
    # loupe
    #
    loupe_initcode = DiamondLoupe.deploy.encode_input()

    print("Loupe: ERADICATE2 -A", diamond_creator_address, "-I", loupe_initcode, "--zero-bytes")

    input("\nPress [enter] to continue")

    # Loupe salt: 0x31c5a4380af0452637d7f2898e2feaf133b45888bc60907a5ecafecb7aabf5c4
    # Loupe address: 0x0000839b00d700280000ede09d2839c7474ed616

    loupe_salt = input("Loupe salt: ")
    loupe_expected_address = input("Loupe address: ")

    # TODO: count the zero bytes?

    loupe_address = mk_contract_address2(diamond_creator_address, loupe_salt, loupe_initcode)

    print("Calculated loupe address:", loupe_address, "\n")

    assert(loupe_expected_address == loupe_address.lower())

    #
    # diamond
    #

    diamond_initcode = Diamond.deploy.encode_input(cutter_address, loupe_address)

    print("Diamond: ERADICATE2 -A", diamond_creator_address, "-I", loupe_initcode, "--zero-bytes")

    input("\nPress [enter] to continue")

    # Diamond salt: 0x2df145a24dd582c3df314a9f60c1dbc9075deaf6675957c58bb5fc4d54fade1f
    # Diamond address: 0x6b17f0bb173300607161a80000e2003292003300
    diamond_salt = input("Diamond salt: ")
    diamond_expected_address = input("Diamond address: ")

    # TODO: count the zero bytes?

    diamond_address = mk_contract_address2(diamond_creator_address, diamond_salt, diamond_initcode)

    print("Calculated diamond_address:", diamond_address, "\n")

    assert(diamond_expected_address == diamond_address.lower())

    # all the rest of the contracts can be searched in parallel

    # TODO: print all the salts and addresses for easy record-keeping

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

    loupe_address = mk_contract_address2(diamond_creator_address, loupe_salt, loupe_initcode)
