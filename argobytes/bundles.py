"""Bundle multiple transactions into as few as possible."""
from abc import ABC, abstractmethod
from pprint import pformat
from typing import List

import click
from brownie import Contract, accounts, chain, network, rpc, web3
from eth_utils.address import is_address

from argobytes.cli_helpers_lite import prompt_loud_confirmation
from argobytes.contracts import get_or_clone_flash_borrower, load_contract
from argobytes.replay import get_upstream_rpc


def find_lenders(aave_lender, borrowed_assets):
    # TODO: allow multiple aave_lenders

    borrowed_assets = borrowed_assets or {}
    lenders = {}
    for asset, amount in borrowed_assets.items():
        # TODO: if this reverts, try another aave_market_id?
        reserve_data = aave_lender.getReserveData(asset)

        lender = reserve_data[7]

        # TODO: make sure the lender has enough tokens

        # unlock the reserve that we are going to be flash loaning from
        # TODO: If enough funds are in on the owner (or other accounts that have approved the clone), we should use those instead
        lenders[asset] = accounts.at(lender, force=True)

    return lenders


class TransactionBundler(ABC):
    """
    Safely send flash loans over the Eden network.

    You can use this in 2 ways:
    1) Extend this, calculate amounts and deploy conracts in __init__,
    override `the_transactions` function to do whatever you want,
    then call careful_send.
    2) Use the `flashloan` function

    TODO: be able to bundle any transactions, not just flash loans
    """

    def __init__(
        self,
        aave_market_id=0,
        aave_provider_registry=None,
        borrowed_assets=None,
        borrower_salt=None,
        clone_salt=None,
        factory_salt=None,
        host_private=None,
        owner=None,
        sender=None,
    ):
        if host_private is None:
            # default to eden. disable by setting to False
            host_private = "https://api.edennetwork.io/v1/rpc"

        # TODO: if "eden" in host_private, make sure sender has at least 100 EDEN staked

        self.owner = owner
        self.host_fork = web3.provider.endpoint_uri
        self.host_private = host_private
        self.host_upstream = get_upstream_rpc()
        self.borrowed_assets = borrowed_assets
        self.borrower_salt = borrower_salt
        self.clone_salt = clone_salt
        self.factory_salt = factory_salt
        self.pending = False
        self.factory = self.flash_borrower = self.clone = self.flash_tx = None
        self.delegate_callable = []  # this is populated by the setup transaction

        assert owner, "no owner!"
        if not sender:
            self.sender = owner
        else:
            self.sender = sender
            raise NotImplementedError("make sure auth is setup for this sender")

        # even if we aren't using Aave, we need the aave_provider_registry to build the ArgobytesFlashBorrower contract
        if aave_provider_registry is None:
            # TODO: DRY
            if chain.id == 1:
                aave_provider_registry = "0x52D306e36E3B6B02c153d0266ff0f85d18BCD413"
            else:
                raise NotImplementedError
        self.aave_provider_registry = load_contract(aave_provider_registry)

        # TODO: if all the assets can be covered by our own balances, skip aave
        aave_providers_list = self.aave_provider_registry.getAddressesProvidersList()

        # TODO: check all the markets and pick the best one
        # #0 is main Aave V2 market. #1 is Aave AMM market
        aave_provider = load_contract(aave_providers_list[aave_market_id])

        self.aave_lender = load_contract(aave_provider.getLendingPool())

        self.lenders = find_lenders(self.aave_lender, self.borrowed_assets)

    def __enter__(self):
        """Context manager that captures transactions for bundling."""
        print("Starting multi-transacation dry run!")

        assert not self.pending, "cannot nest flash loans"
        self.pending = True

        # snapshot here. so we can revert to before any non-atomic transactions are sent
        chain.snapshot()

        return self

    def __exit__(self, exc_type, value, traceback):
        """Context manager that captures transactions for bundling."""

        if exc_type is not None:
            print("Transaction dry run erred!")
            return False

        print("Transaction dry run completed succesfully!")

        self.flash_tx = self._flashloan_from_history()

        self.pending = False

    @abstractmethod
    def setup_bundle(self) -> List[Contract]:
        """Do any setup transactions needed by the bundle (such as approvals).

        Returns a list of delegate callable actions.
        """
        # self.simulated_flash_loan(first_contract_target)
        raise NotImplementedError

    @abstractmethod
    def the_transactions(self):
        """Send a bunch of transactions to be bundled into a flash loan.

        This must call `transfer_from_flash_loan`.
        """
        raise NotImplementedError

    def is_delegate_callable(self, contract):
        address = getattr(contract, "address", contract)
        return address in self.delegate_callable

    def reset_network_fork(self):
        """Kill ganache and start a new one."""
        # TODO: is there some way to list all the unlocked accounts?

        self.set_network_fork()

        # TODO: hide scary error messages
        # TODO: this doesn't work if we started ganache seperately to fork an old block
        rpc.kill()

        network.connect()

        # unlock the accounts again
        for lender in self.lenders:
            print(f"Unlocking {lender}...")
            self.lenders[lender] = accounts.at(lender, force=True)

    def transfer_from_flash_loan(self, receiver):
        """
        # send each asset to the clone just like the flash loan would
        # on a forked network, we transfer from the unlocked lender
        # on mainnet, this transfer is handled by the flash loan function
        # you must call this at the start of `the_transactions`
        """
        for asset, amount in self.borrowed_assets.items():
            assert amount, f"No amount set for {asset}"
            print(f"Simulating flash loan of {amount:_} {asset} to {receiver}...")
            asset.transfer(receiver, amount, {"from": self.lenders[asset]}).info()

    def careful_send(self, prompt_confirmation=True, broadcast=False):
        """Do a dry run, prompt, send the transaction for real."""
        assert web3.provider.endpoint_uri == self.host_fork  # just in case

        # deploy contracts and run any other setup transactions on the forked network
        self.setup()

        # on a forked network, do the transcations that we want to be atomic.
        # the __exit__ funcion compiles everything and sets self.flash_tx
        # TODO: try several different paths and use the best one
        with self:
            self.the_transactions()

        # TODO: if not local account, we cannot proceed

        if not broadcast:
            print("Success! Add --broadcast to send for real.")
            return

        if prompt_confirmation:
            prompt_loud_confirmation(self.owner)

        return self._send_upstream()

    def _send_upstream(self):
        try:
            # send the setup transactions to the upstream network
            self.set_network_upstream()
            self.setup()

            # several blocks may have passed waiting for contract deployment confirmations
            # reset the forked node and rebuild the flash transaction
            self.reset_network_fork()
            with self:
                self.the_transactions()

            # self.safety_checks()  #TODO: figure out how to capture starting balances in a generic way

            # send the flash transaction to the private network
            self.set_network_private()
            tx = self.sender.transfer(
                to=self.flash_tx.receiver,
                data=self.flash_tx.input,
                gas_limit=self.flash_tx.gas_limit,
                allow_revert=False,
            )
            tx.info()
        finally:
            # put the network back
            self.reset_network_fork()

    def set_network_fork(self):
        if self.pending:
            raise RuntimeError

        if web3.provider.endpoint_uri == self.host_fork:
            return

        print("Setting network mode:", click.style("fork", fg="green"))
        network.history.wait()
        network.history.clear()
        web3.connect(self.host_fork)
        web3.reset_middlewares()

    def set_network_upstream(self):
        if self.pending:
            raise RuntimeError

        if web3.provider.endpoint_uri == self.host_upstream:
            return

        print("Setting network mode:", click.style("main", fg="red"))
        network.history.wait()
        network.history.clear()
        web3.connect(self.host_upstream)
        web3.reset_middlewares()

    def set_network_private(self):
        if self.pending:
            raise RuntimeError

        if not self.host_private:
            print("Network mode private is disabled!")
            return self.set_network_upstream()

        if web3.provider.endpoint_uri == self.host_private:
            return

        print("Setting network mode:", click.style("private", fg="yellow"))
        network.history.wait()
        network.history.clear()
        web3.connect(self.host_private)
        web3.reset_middlewares()

    def setup(self):
        # TODO: pass required_confs to these
        self.factory, self.flash_borrower, self.clone = get_or_clone_flash_borrower(
            self.owner,
            aave_provider_registry=self.aave_provider_registry,
            borrower_salt=self.borrower_salt,
            clone_salt=self.clone_salt,
            factory_salt=self.factory_salt,
        )

        # make sure the clone's Aave lending pool address is up-to-date
        # TODO: why are the froms required?
        # TODO: send from sender if they have permissions
        if self.clone.tx:
            tx = self.clone.updateAaveLendingPools({"from": self.owner}).info()
        else:
            try:
                # TODO: does this raise or return false?
                if not self.clone.lending_pools(self.aave_lender):
                    raise ValueError
            except ValueError:
                self.clone.updateAaveLendingPools({"from": self.owner}).info()
                # TODO: remove old pools?

        self.delegate_callable = self.setup_bundle()

        network.history.wait()

    def _actions_from_history(self):
        assert web3.provider.endpoint_uri == self.host_fork, "oh no!"

        # pull actions out of history
        asset_amounts = {}
        actions = []
        for i, tx in enumerate(network.history.from_sender(self.sender)):
            print(f"processing...")
            tx.info()

            contract = load_contract(tx.receiver)

            signature, input_args = contract.decode_input(tx.input)

            # replace any addresses of delegate callable contracts with self.clone
            # TODO: do this more efficiently
            new_input_args = []
            for i in input_args:
                if is_address(i) and self.is_delegate_callable(i):
                    new_input_args.append(self.clone)
                else:
                    new_input_args.append(i)

            """
            # TODO: do this in a more general way? hard coding special cases is really fragile
            # if we are going to transfer from ourselves TO ourselves, so we can just skip it
            if signature == "transfer(address,uint256)" and new_input_args[0] == self.clone:
                # on the forked network, this is transferred from an unlocked account
                # on the live network, this is transferred from the flash lender and so we skip this action
                if contract in asset_amounts:
                    print(f"funding flash loan with {input_args[1]} more {contract}")
                    asset_amounts[contract] += input_args[1]
                else:
                    print(f"funding flash loan with {input_args[1]} {contract}")
                    asset_amounts[contract] = input_args[1]

                continue

            # TODO: is this the right way to cover transferFrom? need tests!
            if signature == "transferFrom(address,address,uint256)" and new_input_args[0] == new_input_args[1]:
                # TODO: i'm not actually sure we will ever do this
                # an action like this is usually part of setup that is only needed on a forked network
                continue
            """

            method = contract.get_method_object(tx.input)

            # sometimes instead of skipping, we want to modify the functions
            # TODO: is this the right way to cover transferFrom? need tests!
            if signature == "transferFrom(address,address,uint256)" and new_input_args[0] == self.clone:
                # TODO: i'm not actually sure we will ever do this
                signature = "transfer(address,uint256)"
                new_input_args = (new_input_args[1], new_input_args[2])
                method = getattr(contract, "transfer")

            # TODO: is this the right way to handle the WethAction? need tests!
            if (
                self.is_delegate_callable(contract)
                and signature == "unwrapAllTo(address)"
                and new_input_args[0] == self.clone
            ):
                # if we are going to delegate call WethAction.unwrapAllTo to ourselves, unwrapAll instead
                signature = "unwrapAll()"
                new_input_args = ()
                method = getattr(contract, "unwrapAll")

            if (
                self.is_delegate_callable(contract)
                and signature == "wrapAllTo(address)"
                and new_input_args[0] == self.clone
            ):
                # if we are going to delegate call WethAction.wrapAllTo to ourselves, wrapAll instead
                signature = "wrapAll()"
                new_input_args = ()
                method = getattr(contract, "wrapAll")

            new_input = method.encode_input(*new_input_args)

            send_balance = bool(tx.value)

            if self.is_delegate_callable(contract):
                # 0 == delegatecall
                action = (tx.receiver, 0, send_balance, new_input)
            else:
                # 1 == call
                action = (tx.receiver, 1, send_balance, new_input)

            actions.append(action)

        # reset history to before we sent the transactions that were bundled into flash_actions
        # TODO: revert until we hit the block height that we expect?
        chain.revert()

        # TODO: if no asset amounts, do this without a flash loan?
        assert asset_amounts, "no asset amounts!"

        return actions, asset_amounts

    def _flashloan_from_history(self):
        """send atomic transaction (on forked network)"""
        flash_actions, asset_amounts = self._actions_from_history()

        flash_params = self.flash_borrower.encodeFlashParams(flash_actions)
        # TODO: encode an array of structs without a web3 call
        # flash_params_2 = eth_abi.encode_abi(['(address,uint8,bytes)[]'], [flash_actions])

        # build parameters for flash loan
        lenders = []
        assets = []
        amounts = []
        modes = []
        for asset, amount in asset_amounts.items():
            lenders.append(self.lenders[asset])
            assets.append(asset)
            amounts.append(amount)
            # TODO: allow taking on debt?
            modes.append(0)

        print("clone:  ", self.clone)
        print("lenders:", pformat(lenders))
        print("assets: ", pformat(assets))
        print("amounts:", pformat(amounts))
        print("modes:  ", pformat(modes))
        print("actions:", pformat(flash_actions))

        print("Sending dry run of Aave flash loan transaction...")
        # TODO: if any of the lenders are aave, use an aave flash loan. otherwise call self.clone.flashloanForOwner(...)
        flash_tx = self.aave_lender.flashLoan(
            self.clone, assets, amounts, modes, self.clone, flash_params, 0, {"from": self.sender}
        )

        # TODO: info for reverted trasactions was crashing ganachhe
        if flash_tx.status == 1:
            flash_tx.info()
            flash_tx.call_trace()

        return flash_tx
