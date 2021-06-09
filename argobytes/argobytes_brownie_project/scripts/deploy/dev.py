# deploy all our contracts to a development network
# rather than call this directly, you probably want to use `./scripts/test-deploy.sh` or `./scripts/staging-deploy.sh`
# TODO: refactor to use argobytes_utils helpers

from brownie import *
from brownie.network import gas_price

from argobytes.addresses import *
from argobytes.contracts import ArgobytesBrownieProject, ArgobytesInterfaces, get_or_clone_flash_borrower, get_or_create

# TODO: set these inside main instead of using globals
# EXPORT_ARTIFACTS = os.environ.get("EXPORT_ARTIFACTS", "0") == "1"
# DEPLOY_DIR = os.path.join(
#     project.main.check_for_project("."), "build", "deployments", "quick_and_dirty"
# )


# def quick_save_contract(contract):
#     quick_save(contract._name, contract.address)


# def quick_save(contract_name, address):
#     """quick and dirty way to save contract addresses in an easy to read format."""
#     if EXPORT_ARTIFACTS == False:
#         print(f"{contract_name} is deployed at {address}\n")
#         return

#     quick_name = contract_name + ".json"

#     quick_path = os.path.join(DEPLOY_DIR, quick_name)

#     print(f"Saving deployed address to {quick_path}")

#     with open(quick_path, "w") as opened_file:
#         opened_file.write(json.dumps(address))


def main():
    # os.makedirs(DEPLOY_DIR, exist_ok=True)

    print("account 0:", accounts[0])

    # todo: automatic price to match mainnet default speed
    gas_price("20 gwei")

    argobytes_tip_address = web3.ens.resolve("tip.satoshiandkin.eth")

    print(f"argobytes_tip_address: {argobytes_tip_address}")

    argobytes_flash_borrower_arbitragers = [
        accounts[0],
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[4],
    ]

    starting_balance = accounts[0].balance()

    # TODO: docs for using ERADICATE2
    # TODO: openzepplin helper uses bytes32, but gastoken uses uint256.
    salt = ""

    # deploy a dsproxy just to compare gas costs
    # TODO: whats the deploy cost of DSProxyFactory?
    ds_proxy_factory = ArgobytesInterfaces.DSProxyFactory(DSProxyFactoryAddress, accounts[5])
    ds_proxy_factory.build()

    # deploy ArgobytesFactory
    # deploy ArgobytesFlashBorrower
    # clone ArgobytesFlashBorrower for accounts[0]
    (argobytes_factory, argobytes_flash_borrower, argobytes_clone) = get_or_clone_flash_borrower(
        accounts[0],
    )

    # deploy ArgobytesAuthority
    argobytes_authority = get_or_create(accounts[0], ArgobytesBrownieProject.ArgobytesAuthority, salt=salt)

    # quick_save_contract(argobytes_authority)

    # TODO: setup auth for the proxy
    # for now, owner-only access works, but we need to allow a bot in to call atomicArbitrage

    # deploy the main contracts
    get_or_create(accounts[0], ArgobytesBrownieProject.ArgobytesMulticall)

    # deploy base actions
    argobytes_trader = get_or_create(accounts[0], ArgobytesBrownieProject.ArgobytesTrader)

    # deploy all the exchange actions
    get_or_create(accounts[0], ArgobytesBrownieProject.ExampleAction)
    # get_or_create(accounts[0], ArgobytesBrownieProject.OneSplitOffchainAction)
    kyber_action = get_or_create(
        accounts[0], ArgobytesBrownieProject.KyberAction, constructor_args=[argobytes_tip_address]
    )
    get_or_create(accounts[0], ArgobytesBrownieProject.UniswapV1Action)
    get_or_create(accounts[0], ArgobytesBrownieProject.UniswapV2Action)
    # get_or_create(accounts[0], ArgobytesBrownieProject.ZrxV3Action)
    get_or_create(accounts[0], ArgobytesBrownieProject.Weth9Action)
    get_or_create(accounts[0], ArgobytesBrownieProject.CurveFiAction)

    # deploy leverage cyy3crv actions
    get_or_create(accounts[0], ArgobytesBrownieProject.EnterCYY3CRVAction)
    get_or_create(accounts[0], ArgobytesBrownieProject.ExitCYY3CRVAction)

    get_or_create(accounts[0], ArgobytesBrownieProject.EnterUnit3CRVAction)
    # get_or_create(accounts[0], ArgobytesBrownieProject.ExitUnit3CRVAction)

    bulk_actions = [
        # allow bots to call argobytes_trader.atomicArbitrage
        # TODO: allow bots to flash loan from WETH10 and DyDx and Uniswap and any other wrappers that we trust
        # TODO: think about this more
        (
            argobytes_authority,
            0,  # 0=CALL
            False,
            argobytes_authority.allow.encode_input(
                argobytes_flash_borrower_arbitragers,
                argobytes_trader,
                0,  # 0=CALL
                argobytes_trader.atomicArbitrage.signature,
            ),
        ),
    ]

    argobytes_clone.executeMany(bulk_actions)

    print("gas used by accounts[0]:", accounts[0].gas_used)

    ending_balance = accounts[0].balance()

    assert ending_balance < starting_balance

    print("ETH used by accounts[0]:", (starting_balance - ending_balance) / 1e18)

    """
    # save all the addresses we might use, not just ones for own contracts
    quick_save("CurveFiBUSD", CurveFiBUSDAddress)
    quick_save("CurveFiCompound", CurveFiCompoundAddress)
    quick_save("CurveFiPAX", CurveFiPAXAddress)
    quick_save("CurveFiREN", CurveFiRENAddress)
    quick_save("CurveFiSUSDV2", CurveFiSUSDV2Address)
    quick_save("CurveFiTBTC", CurveFiTBTCAddress)
    quick_save("CurveFiUSDT", CurveFiUSDTAddress)
    quick_save("CurveFiY", CurveFiYAddress)
    quick_save("KollateralInvoker", KollateralInvokerAddress)
    quick_save("KyberNetworkProxy", KyberNetworkProxyAddress)
    quick_save("KyberRegisterWallet", KyberRegisterWalletAddress)
    quick_save("OneSplit", OneSplitAddress)
    quick_save("SynthetixAddressResolver", SynthetixAddressResolverAddress)
    quick_save("UniswapFactory", UniswapV1FactoryAddress)
    quick_save("UniswapV2Router", UniswapV2RouterAddress)
    quick_save("YearnWethVault", YearnWethVaultAddress)

    # TODO: this list is going to get long. use tokenlists.org instead
    quick_save("DAI", DAIAddress)
    quick_save("cDAI", cDAIAddress)
    quick_save("cUSDC", cUSDCAddress)
    quick_save("sUSD", ProxysUSDAddress)
    quick_save("USDC", USDCAddress)
    quick_save("COMP", COMPAddress)
    quick_save("AAVE", AAVEAddress)
    quick_save("LINK", LINKAddress)
    quick_save("MKR", MKRAddress)
    quick_save("SNX", SNXAddress)
    quick_save("WBTC", WBTCAddress)
    quick_save("YFI", YFIAddress)
    quick_save("WETH9", WETH9Address)
    quick_save("yvyCRV", YVYCRVAddress)
    """

    # # give the argobytes_flash_borrower a bunch of coins. it will forward them when deploying the diamond
    # accounts[1].transfer(DevHardwareAddress, 50 * 1e18)
    # accounts[2].transfer(DevHardwareAddress, 50 * 1e18)
    # accounts[3].transfer(DevHardwareAddress, 50 * 1e18)
    # accounts[4].transfer(DevMetamaskAddress, 50 * 1e18)

    # make a clone vault w/ auth for accounts[5] and approve a bot to call atomicArbitrage. then print total gas
    starting_balance = accounts[5].balance()

    deploy_tx = argobytes_factory.createClone19(
        argobytes_flash_borrower.address,
        salt,
        {"from": accounts[5]},
    )

    argobytes_flash_borrower_clone_5 = ArgobytesBrownieProject.ArgobytesFlashBorrower.at(
        deploy_tx.return_value, accounts[5]
    )

    bulk_actions = [
        # allow bots to call argobytes_trader.atomicArbitrage
        # TODO: think about this more. the msg.sender might not be what we need
        (
            argobytes_authority,
            0,  # 0=Call
            False,
            argobytes_authority.allow.encode_input(
                argobytes_flash_borrower_arbitragers,
                argobytes_trader,
                1,  # 1=delegatecall
                argobytes_trader.atomicArbitrage.signature,
            ),
        ),
        # TODO: gas_token.buyAndFree or gas_token.free depending on off-chain balance/price checks
    ]

    argobytes_flash_borrower_clone_5.executeMany(bulk_actions)

    ending_balance = accounts[5].balance()

    print(
        "ETH used by accounts[5] to deploy a proxy with auth:",
        (starting_balance - ending_balance) / 1e18,
    )

    # make a clone for accounts[6]. then print total gas
    starting_balance = accounts[6].balance()

    # TODO: optionally free gas token
    deploy_tx = argobytes_factory.createClone19(
        argobytes_flash_borrower.address,
        salt,
        {"from": accounts[6]},
    )

    argobytes_flash_borrower_clone_6 = ArgobytesBrownieProject.ArgobytesFlashBorrower.at(
        deploy_tx.return_value, accounts[6]
    )

    ending_balance = accounts[6].balance()

    print(
        "ETH used by accounts[6] to deploy a proxy:",
        (starting_balance - ending_balance) / 1e18,
    )

    # make a clone for accounts[7]. then print total gas
    starting_balance = accounts[7].balance()

    deploy_tx = argobytes_factory.createClone19(
        argobytes_flash_borrower.address,
        salt,
        accounts[7],
        {"from": accounts[7]},
    )

    argobytes_flash_borrower_clone_7 = ArgobytesBrownieProject.ArgobytesFlashBorrower.at(
        deploy_tx.return_value, accounts[7]
    )

    ending_balance = accounts[7].balance()

    print(
        "ETH used by accounts[7] to deploy a proxy:",
        (starting_balance - ending_balance) / 1e18,
    )

    # reset_block_time(synthetix_depot_action)
