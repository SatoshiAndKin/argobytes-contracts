# TODO: make a class that does atomic transactions via the flash loaner smart contract
import click
import eth_abi
from brownie import chain, history, network, rpc, web3
from brownie._config import CONFIG
from eth_utils.address import is_address
from hexbytes import HexBytes

from argobytes.contracts import ArgobytesBrownieProject, get_or_clone_flash_borrower, load_contract


class ArgobytesFlashManager:
    """
    Safely send flash loans.

    Extend this, do setup in __init__, and override `the_transactions` function to do whatever you want

    # TODO: rename to ArgobytesAtomicTransaction and have it be smart about flash loans or borrowing from owner
    """

    def __init__(
        self,
        owner,
        asset_amounts,
        borrower_salt=None,
        clone_salt=None,
        factory_salt=None,
        host_private="https://api.edennetwork.io/v1/rpc",
        setup_transactions=None,
        delegate_callable=None,
    ):
        active_network = CONFIG.active_network

        assert active_network["id"].endswith("-fork")

        forked_host = active_network["cmd_settings"]["fork"]
        assert forked_host.startswith("http"), "only http supported for now"

        self.host_fork = web3.provider.endpoint_uri
        self.host_main = forked_host
        self.host_private = host_private
        self.owner = owner
        self.asset_amounts = asset_amounts
        self.borrower_salt = borrower_salt
        self.clone_salt = clone_salt
        self.factory_salt = factory_salt
        self.setup_transactions = setup_transactions or []

        self.backup_history_fork = None
        self.backup_history_main = None
        self.backup_history_private = None

        self.aave_provider_registry = load_contract("0x52D306e36E3B6B02c153d0266ff0f85d18BCD413")

        # #0 is main Aave V2 market. #1 is Aave AMM market
        self.aave_provider = load_contract(self.aave_provider_registry.getAddressesProvidersList()[0])
        self.aave_lender = load_contract(self.aave_provider.getLendingPool(), self.owner)

        self.pending = False
        self.factory = self.flash_borrower = self.clone = self.flash_tx = None
        self.ignore_txids = []
        self.delegate_callable = [getattr(dc, "address") for dc in delegate_callable]

    def __enter__(self):
        """Context manager that captures transactions for bundling."""
        print("Starting multi-transacation dry run!")

        assert not self.pending, "cannot nest flash loans"
        self.pending = True

        # save the index that we start at
        self.old_history = len(history)

        # snapshot here. so we can revert to before any non-atomic transactions are sent
        chain.snapshot()

        return self

    def __exit__(self, exc_type, value, traceback):
        """Context manager that captures transactions for bundling."""
        print("Multiple transaction dry run complete!")

        if exc_type != None:
            # we got an exception
            return False

        self._flashloan_from_history()

        self.pending = False
        self.ignore_txids.clear()

    def backup_history(self):
        # TODO: test this!
        if web3.provider.endpoint_uri == self.host_fork:
            if self.backup_history_fork:
                history = self.backup_history_fork.copy()
            else:
                history.clear()
            self.backup_history_fork = None
        elif web3.provider.endpoint_uri == self.host_main:
            if self.backup_history_main:
                history = self.backup_history_main.copy()
            else:
                history.clear()
            self.backup_history_main = None
        elif web3.provider.endpoint_uri == self.host_private:
            if self.backup_history_private:
                history = self.backup_history_private.copy()
            else:
                history.clear()
            self.backup_history_private = None
        else:
            raise ValueError

    def ignore_tx(self, tx):
        """If you do a transaction during __init__ that you do not want replayed on mainnet, ignore it."""
        self.ignore_txids.append(tx.txid)

    def is_delegate_callable(self, contract):
        address = contract.getattr("address", contract)
        return address in self.delegate_callable

    def reset_network_fork(self):
        """Kill ganache and start a new one."""
        # TODO: this doesn't work well if we started ganache seperately
        self.set_network_fork()
        # TODO: hide scary error messages
        rpc.kill()
        network.connect()

    def restore_history(self):
        # TODO: test this. do we even need it? is it fine to just clear history whenever we switch?
        if web3.provider.endpoint_uri == self.host_fork:
            self.backup_history_fork = history.clone()
        elif web3.provider.endpoint_uri == self.host_main:
            self.backup_history_main = history.clone()
        elif web3.provider.endpoint_uri == self.host_private:
            self.backup_history_private = history.clone()
        else:
            raise ValueError

    def safe_run(self, prompt_confirmation=True):
        """Do a dry run, prompt, send the transaction for real."""
        # TODO: this could be a nice flow. think about this some more and then make it part of the class that arb_eth and arb_crv use

        assert web3.provider.endpoint_uri == self.host_fork  # just in case

        # deploy contracts and run any other setup transactions on the forked network
        setup_did_something = self.setup() > 0

        # on a forked network, do the transcations that we want to be atomic.
        # the __exit__ funcion compiles everything and sets self.flash_tx
        # TODO: try several different paths and use the best one
        with self:
            self.the_transactions()

        if prompt_confirmation:
            # TODO: print expected gas costs
            # TODO: safety check on gas costs
            # TODO: different chains have different token names.
            click.confirm("Are you sure you want to spend ETH?", abort=True)

        self.set_network_main()

        if setup_did_something:
            # deploy the setup transactions for real
            self.setup()

            # several blocks may have passed waiting for contract deployment confirmations
            # reset the forked node and rebuild the transaction
            self.reset_network_fork()

            # rebuild the atomic transaction
            with self:
                self.the_transactions()

            # self.safety_checks()  #TODO: figure out how to capture starting balances in a generic way

            # prepare to send the transaction for real
            self.set_network_main()

        raise NotImplementedError("send for real")
        # self._send_for_real()

    def set_network_fork(self):
        if self.pending:
            raise RuntimeError

        if web3.provider.endpoint_uri == self.host_fork:
            return

        self.backup_history()

        print("Setting network mode:", click.style("fork", fg="green"))
        web3.provider.endpoint_uri = self.host_fork

        self.restore_history()

    def set_network_main(self):
        if self.pending:
            raise RuntimeError

        if web3.provider.endpoint_uri == self.host_fork:
            return

        self.backup_history()

        print("Setting network mode:", click.style("main", fg="red"))
        web3.provider.endpoint_uri = self.host_main

        self.restore_history()

    def set_network_private(self):
        if self.pending:
            raise RuntimeError

        if self.host_private:
            if web3.provider.endpoint_uri == self.host_private:
                return

            self.backup_history()

            print("Setting network mode:", click.style("private", fg="yellow"))
            web3.provider.endpoint_uri = self.host_private

            self.restore_history()

            return

        print("Network mode private is disabled!")
        self.set_network_main()

    def setup(self) -> int:
        start_history_len = len(history)

        # TODO: pass required_confs to these
        self.factory, self.flash_borrower, self.clone = get_or_clone_flash_borrower(
            self.owner,
            constructor_args=[self.aave_provider_registry],
            borrower_salt=self.borrower_salt,
            clone_salt=self.clone_salt,
            factory_salt=self.factory_salt,
        )

        # make sure the clone's Aave lending pool address is up-to-date
        # TODO: why are the froms required?
        if self.clone.tx:
            tx = self.clone.updateLendingPools({"from": self.owner})
            tx.info()
        else:
            try:
                # TODO: does this raise or return false?
                if not self.clone.lending_pools(self.aave_lender):
                    raise ValueError
            except ValueError:
                tx = self.clone.updateLendingPools({"from": self.owner})
                tx.info()
                # TODO: remove old pools?

        # run any extra setup transactions
        for tx in self.setup_transactions:
            if not tx:
                continue

            if tx.txid in self.ignore_txids:
                continue

            # TODO: get the actual Contract for this so brownie's info is better?
            # TODO: if we set gas_limit and allow_revert=False, how does it check for revert?
            # TODO: are we suure required_confs=0 is always going to be okay?
            self.owner.transfer(
                to=tx.receiver,
                data=tx.input,
                gas_limit=tx.gas_limit,
                allow_revert=False,
                required_confs=0,
            )

        history.wait()

        return len(history) - start_history_len

    def the_transactions(self):
        """Send a bunch of transactions to be bundled into a flash loan."""
        raise NotImplementedError("proper abstract base class")

    def _actions_from_history(self):
        assert web3.provider.endpoint_uri == self.host_fork, "oh no!"

        # pull actions out of history
        actions = []
        for tx in network.history:
            if tx.txid in self.ignore_txids:
                continue

            # TODO: logging

            contract = load_contract(tx.receiver)

            signature, input_args = contract.decode_input(tx.input)

            if signature == "transfer(address,uint256)" and self.is_delegate_callable(input_args[0]):
                # skip transfers to an action if we are going to delegate call the action
                continue

            # replace any addresses of delegate callable contracts with self.clone
            # TODO: do this more efficiently
            new_input_args = []
            for i in input_args:
                if is_address(i) and self.is_delegate_callable(i):
                    new_input_args.append(self.clone)
                else:
                    new_input_args.append(i)

            method = contract.get_method_object(tx.input)
            new_input = HexBytes(method.encode_input(*new_input_args))

            send_balance = bool(tx.value)

            if self.is_delegate_callable(contract):
                # 0 == delegatecall
                action = (tx.receiver, 0, send_balance, new_input)
            else:
                # 1 == call
                action = (tx.receiver, 1, send_balance, new_input)

            actions.append(action)

        # reset history to before we sent the transactions that were bundled into flash_actions
        chain.revert()
        network.history = self.old_history

        return actions

    def _flashloan_from_history(self):
        """send atomic transaction (on forked network)"""
        flash_actions = self._actions_from_history()

        flash_params = self.flash_borrower.encodeFlashParams(flash_actions)
        # TODO: encode an array of structs without a web3 call
        # flash_params_2 = eth_abi.encode_abi(['(address,uint8,bytes)[]'], [flash_actions])

        # build parameters for flash loan
        assets = []
        amounts = []
        modes = []
        for asset, amount in self.asset_amounts.items():
            assets.append(asset)
            amounts.append(amount)
            modes.append(0)

        print("Sending dry run of atomic transaction...")
        self.flash_tx = self.aave_lender.flashLoan(
            self.clone, assets, amounts, modes, self.clone, flash_params, 0, {"from": self.owner}
        )
        self.flash_tx.info()

    def _send_for_real(self):
        print("Sending the transaction for real!")
        assert self.flash_tx, "no pending transaction"

        self.set_network_private()

        # send the transaction to be confirmed on the real chain
        # TODO: use the same gas estimate?
        tx = self.owner.transfer(
            to=self.flash_tx.receiver,
            data=self.flash_tx.input,
            gas_limit=self.flash_tx.gas_limit,
            allow_revert=False,
        )
        tx.info()

        # set the provide back to the forked network
        self.reset_network_fork()

        return tx
