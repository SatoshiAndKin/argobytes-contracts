from brownie import *
from eth_abi.packed import encode_abi_packed
from eth_utils import keccak, to_checksum_address, to_bytes
import os
import rlp


def deploy2_and_free(gas_token, diamond_contract, deploy_salt, contract_to_deploy, contract_to_deploy_args, gas_price):
    """Use a diamond's deploy2 and free helper function."""
    contract_initcode = contract_to_deploy.deploy.encode_input(*contract_to_deploy_args)

    # TODO: print the expected address for this target_salt and contract_initcode

    deploy_tx = diamond_contract.deploy2AndFree(
        gas_token,
        deploy_salt,
        contract_initcode,
        {"from": accounts[0], "gasPrice": gas_price}
    )

    if hasattr(deploy_tx, "return_value"):
        # this should be the normal path
        deployed_address = deploy_tx.return_value
    else:
        # print(deploy_tx.events)

        # i think this is a bug
        # no return_value, so we check logs instead
        # TODO: i don't think this log should be needed
        events = deploy_tx.events['Deploy'][0]

        deployed_address = events['deployed']

    contract_to_deploy = contract_to_deploy.at(deployed_address)

    print("CREATE2 deployed:", contract_to_deploy._name, "to", contract_to_deploy.address)
    print()

    return contract_to_deploy


def deploy2_and_cut_and_free(gas_token, diamond_contract, deploy_salt, contract_to_deploy, contract_to_deploy_args, deployed_sigs, gas_price):
    contract_initcode = contract_to_deploy.deploy.encode_input(*contract_to_deploy_args)

    # TODO: print the expected address for this target_salt and initcode

    # TODO: deploy2AndDiamondCutAndFree
    deploy_tx = diamond_contract.deploy2AndFree(
        gas_token,
        deploy_salt,
        contract_initcode,
        {"from": accounts[0], "gasPrice": gas_price}
    )

    if hasattr(deploy_tx, "return_value"):
        # this should be the normal path
        deployed_address = deploy_tx.return_value
    else:
        # print(deploy_tx.events)

        # i think this is a bug
        # no return_value, so we check logs instead
        # TODO: i don't think this log should be needed
        events = deploy_tx.events['Deploy'][0]

        deployed_address = events['deployed']

    # TODO: make sure we got the address that we expected

    contract_to_deploy = contract_to_deploy.at(deployed_address)

    print("CREATE2 deployed:", contract_to_deploy._name, "to", contract_to_deploy.address)
    print()

    # add the functions to the diamond
    encoded_sigs = []
    for deployed_sig in deployed_sigs:
        # TODO: whats the maximum number of selectors?
        cut = to_bytes(hexstr=contract_to_deploy.signatures[deployed_sig])

        encoded_sigs.append(cut)

    # TODO: whats the maximum number of selectors?
    # abi.encodePacked(address, selector1, ..., selectorN)
    encoded_sigs = encode_abi_packed(
        ['address'] + ['bytes4'] * len(encoded_sigs),
        [deployed_address] + encoded_sigs
    )

    # TODO: do a bunch of these in one transaction
    # cut_tx = diamond_contract.diamondCutAndFree(
    #     gas_token,
    #     [encoded_sigs],
    #     "0x0000000000000000000000000000000000000000",
    #     to_bytes(hexstr="0x"),
    #     {"from": accounts[0], "gasPrice": gas_price}
    # )

    return (contract_to_deploy, encoded_sigs)


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

    address_bytes = keccak(raw)[12:]

    return to_checksum_address(address_bytes)


def reset_block_time(synthetix_depot_action):
    # synthetix_address_resolver = interface.IAddressResolver(SynthetixAddressResolver)

    # TODO: get this from the address resolver instead
    synthetix_exchange_rates = Contract.from_explorer("0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77")

    token_bytestr = synthetix_depot_action.BYTESTR_ETH()

    last_update_time = synthetix_exchange_rates.lastRateUpdateTimes(token_bytestr)

    print("last_update_time: ", last_update_time)

    assert last_update_time != 0

    latest_block_time = web3.eth.getBlock(web3.eth.blockNumber).timestamp

    print("latest_block_time:", latest_block_time)

    assert latest_block_time != 0

    web3.testing.mine(last_update_time)
