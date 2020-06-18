from eth_utils import keccak, to_checksum_address, to_bytes
import os
import rlp


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
    raw = rlp.encode([
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
