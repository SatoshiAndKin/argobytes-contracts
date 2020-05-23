import json
from brownie import *

CurveCompounded = "0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56"
CurveUSDT = "0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C"
CurveY = "0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51"
CurveB = "0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27"
CurveSUSDV2 = "0xA5407eAE9Ba41422680e2e00537571bcC53efBfD"
CurvePAX = "0x06364f10B501e868329afBc005b3492902d6C763"
GasTokenAddress = "0x0000000000b3F879cb30FE243b4Dfee438691c04"
KollateralInvokerAddress = "0x06d1f34fd7C055aE5CA39aa8c6a8E10100a45c01"
KyberRegisterWallet = "0xECa04bB23612857650D727B8ed008f80952654ee"
OneSplitAddress = "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E"
Weth9Address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
KyberNetworkProxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
# https://contracts.synthetix.io/ReadProxyAddressResolver
SynthetixAddressResolver = "0x4E3b31eB0E5CB73641EE1E65E7dCEFe520bA3ef2"
UniswapFactory = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"


def query_until_yes(question, default=None):
    """Ask a yes/no question via raw_input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    valid = {"yes": True, "y": True, "ye": True}
    if default is None:
        prompt = " [y] "
    elif default == "yes":
        prompt = " [Y] "
    elif default == "no":
        prompt = " [y] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        print(question + prompt, end='')
        choice = input().lower()
        if default is not None and choice == '':
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            print("Please respond with 'yes' (or 'y').\n")


def deploy_helper(contract, *constructor_params):
    name = contract._name

    # bytecodeWithParams = contract.deploy.encode_input(*constructor_params)

    # print(name, "bytecodeWithParams:", "0x" + bytecodeWithParams)

    print(name, "bytecode WITHOUT PARAMS:\n\n", "0x" + contract.bytecode)
    print("")
    print(name, "abi:\n\n", json.dumps(contract.abi))
    print("")
    print(name, "params: ", constructor_params)

    deployed_address = input(" ".join(["Input deployed address for", name, ": "]))

    query_until_yes("Deployment transaction confirmed?")

    return contract.at(deployed_address)


def transaction_helper(description, contract, function, *function_params, wait_for_confirm=True):
    unsigned_transaction = function.encode_input(*function_params)

    # TODO: do something to recommend a gas limit? mew seems to handle that for us

    print("Sign and send this transaction:", contract, unsigned_transaction)

    if wait_for_confirm:
        query_until_yes(" ".join(["Transaction", description, "confirmed?"]))


def send_eth_helper(to, amount, wait_for_confirm=True):
    print("Now send", amount, "ETH to", to)

    if wait_for_confirm:
        query_until_yes("Transaction sending ETH confirmed?")


def main():
    assert False, "this need to be rewritten to use CREATE2"

    # TODO: multiple, comma seperated addresses
    arb_bot = input(
        "Input arb bot address: [0x52517b7b19D3CA0Bd66c604BC1909D2c9951dbD5] ") or "0x52517b7b19D3CA0Bd66c604BC1909D2c9951dbD5"

    arb_bots = [
        arb_bot
    ]

    argobytes_atomic_trade = ArgobytesAtomicTrade.deploy(
        KollateralInvokerAddress, {'from': accounts[0]})

    argobytes_owned_vault = ArgobytesOwnedVault.deploy(
        GasTokenAddress, arb_bots, argobytes_atomic_trade, {'from': accounts[0]})

    # this one is small and should deploy fast, so do it first
    deploy_helper(Weth9Action, Weth9Address)

    deploy_helper(CurveFiAction, CurveCompounded, 2)
    deploy_helper(CurveFiAction, CurveUSDT, 3)
    deploy_helper(CurveFiAction, CurveY, 4)
    deploy_helper(CurveFiAction, CurveB, 4)
    deploy_helper(CurveFiAction, CurveSUSDV2, 4)
    deploy_helper(CurveFiAction, CurvePAX, 4)
    deploy_helper(UniswapV1Action, UniswapFactory)
    deploy_helper(KyberAction, KyberNetworkProxy, argobytes_owned_vault)
    deploy_helper(OneSplitOffchainAction, OneSplitAddress)
    deploy_helper(SynthetixDepotAction, SynthetixAddressResolver)

    # security
    transaction_helper(
        "set trusted trader role on ArgobytesAtomicTrade",
        argobytes_atomic_trade,
        argobytes_atomic_trade.grantRole,
        argobytes_atomic_trade.TRUSTED_TRADER_ROLE(),
        argobytes_owned_vault,
        wait_for_confirm=False,
    )

    # register for the kyber fee sharing program
    kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWallet)

    transaction_helper(
        "register Kyber wallet",
        kyber_register_wallet,
        kyber_register_wallet.registerWallet,
        argobytes_owned_vault,
        wait_for_confirm=False,
    )

    send_eth_helper(argobytes_owned_vault, 0.5 * 1e18, wait_for_confirm=False)
