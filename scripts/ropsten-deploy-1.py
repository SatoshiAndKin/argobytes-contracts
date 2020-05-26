# UNDER CONSTRUCTION!
# Helper to deploy to ropsten

import json
from brownie import *

CurveCompounded = "0x33b4161732B863B8C79957D1D75660F4E33a60bE"
# CurveUSDT = ""
# CurveY = ""
# CurveB = ""
# CurveSUSDV2 = ""
# CurvePAX = ""
# GasTokenAddress = "0x0000000000b3F879cb30FE243b4Dfee438691c04"
GasTokenAddress = "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c"
KollateralInvokerAddress = "0x234A76352e816c48098F20F830A21c820085b902"
OneSplitAddress = ""
Weth9Address = "0xc778417e063141139fce010982780140aa0cd5ab"
KyberNetworkProxy = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
# Kyber doesn't have KyberRegisterWallet on ropsten
KyberRegisterWallet = ""
# https://contracts.synthetix.io/ropsten/ReadProxyAddressResolver
SynthetixAddressResolver = "0x4da3B8fb742BC69531Ec7AdBAa06effDEd1A22BA"
UniswapFactory = "0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351"

# from Curve's logs - https://github.com/curvefi/curve-contract/blob/pool_compound/deployed/2020-03-25_ropsten_compound/ropsten.log
DAI = "0xB5E5D0F8C0cbA267CD3D7035d6AdC8eBA7Df7Cdd"
USDC = "0x8a9447df1FB47209D36204e6D56767a33bf20f9f"
cDAI = "0x6CE27497A64fFFb5517AA4aeE908b1E7EB63B9fF"
cUSDC = "0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF"


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

    arb_bot = input(
        "Input arb bot address: [0x52517b7b19D3CA0Bd66c604BC1909D2c9951dbD5] ") or "0x52517b7b19D3CA0Bd66c604BC1909D2c9951dbD5"

    arb_bots = [
        arb_bot
    ]

    argobytes_atomic_trade = ArgobytesAtomicTrade.deploy(
        KollateralInvokerAddress, {'from': accounts[0]})

    argobytes_owned_vault = ArgobytesOwnedVault.deploy(
        GasTokenAddress, arb_bots, argobytes_atomic_trade, {'from': accounts[0]})

    # deploy_helper(OneSplitOffchainAction, OneSplitAddress)
    deploy_helper(KyberAction, KyberNetworkProxy, argobytes_owned_vault)
    deploy_helper(UniswapV1Action, UniswapFactory)
    deploy_helper(Weth9Action, Weth9Address)
    deploy_helper(SynthetixDepotAction, SynthetixAddressResolver)
    deploy_helper(CurveFiAction, CurveCompounded, 2)
    # deploy_helper(CurveFiAction, CurveUSDT, 3)
    # deploy_helper(CurveFiAction, CurveY, 4)
    # deploy_helper(CurveFiAction, CurveB, 4)
    # deploy_helper(CurveFiAction, CurveSUSDV2, 4)
    # deploy_helper(CurveFiAction, CurvePAX, 4)

    transaction_helper(
        "set trusted trader role on ArgobytesAtomicTrade",
        argobytes_atomic_trade,
        argobytes_atomic_trade.grantRole,
        argobytes_atomic_trade.TRUSTED_TRADER_ROLE(),
        argobytes_owned_vault,
        wait_for_confirm=False,
    )

    # kyber_register_wallet = interface.KyberRegisterWallet(KyberRegisterWallet)
    # transaction_helper("register Kyber wallet", kyber_register_wallet,
    #                    kyber_register_wallet.registerWallet, argobytes_owned_vault, wait_for_confirm=False)

    send_eth_helper(argobytes_owned_vault, 0.5 * 1e18, wait_for_confirm=False)
