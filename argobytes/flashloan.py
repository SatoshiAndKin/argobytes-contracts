# TODO: make a class that does atomic transactions via the flash loaner smart contract
from brownie import chain, network, rpc, web3
from brownie._config import CONFIG
from brownie.network import history

from argobytes.contracts import get_or_clone_flash_borrower, load_contract


# TODO: option to borrow from owner instead of Aave
class ArgobytesFlashManager:
    def __init__(
        self,
        owner,
        asset_amounts,
        borrower_salt=None,
        clone_salt=None,
        factory_salt=None,
        setup_transactions=None,
        host_private="https://api.edennetwork.io/v1/rpc",
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

        self.aave_provider_registry = load_contract("0x52D306e36E3B6B02c153d0266ff0f85d18BCD413")

        # #0 is main Aave V2 market. #1 is Aave AMM market
        self.aave_provider = load_contract(self.aave_provider_registry.getAddressesProvidersList()[0])
        self.aave_lender = load_contract(self.aave_provider.getLendingPool(), self.owner)

        self.pending = False
        self.factory = self.flash_borrower = self.clone = self.flash_tx = None
        self.ignore_txids = []

    def reset_network_fork(self):
        self.set_network_fork()
        rpc.kill()
        network.connect()

    def set_network_private(self):
        history.clear()
        web3.provider.endpoint_uri = self.host_private

    def set_network_fork(self):
        history.clear()
        web3.provider.endpoint_uri = self.host_fork

    def set_network_main(self):
        history.clear()
        web3.provider.endpoint_uri = self.host_main

    def safe_run(self, action_func, prompt_confirmation=True):
        """Do a dry run, prompt, send the transaction for real."""
        # TODO: this could be a nice flow. think about this some more and then make it part of the class that arb_eth and arb_crv use

        self.set_network_fork()  # just in case

        # deploy contracts and run any other setup transactions on the forked network
        setup_did_something = self.setup()

        # do the thing that we want to be atomic.
        # the __exit__ funcion compiles everything and sets self.flash_tx
        with self:
            action_func()
        
        if prompt_confirmation:
            # TODO: print expected gas costs
            click.confirm("Are you sure you want to spend ETH?", abort=True)

        self.set_network_main()

        # deploy the contracts for real
        if setup_did_something:
            self.setup()

            # several blocks may have passed waiting for contract deployment confirmtions. reset the forked node
            self.reset_network_fork()

            # rebuild the atomic transaction
            with self:
                action_func()
        
            # prepare to send the transaction for real
            self.set_network_main()

        raise NotImplementedError("send for real")
        # self.send_for_real()

    def setup(self):
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
        for setup_tx in self.setup_transactions:
            if not setup_tx:
                continue

            # TODO: this seems wrong. only do this if
            # tx is set, so the contract was deployed by this instance of brownie
            # TODO: required_confs = 0
            tx = self.owner.transfer(
                to=required_contract.tx.receiver,
                data=required_contract.tx.input,
                gas_limit=required_contract.tx.gas_limit,
                allow_revert=False,
            )
            # TODO: get the actual Contract for this so brownie's info is better?
            # TODO: run all these in parallel
            tx.info()

    def __enter__(self):
        print("Starting dry run!")

        assert not self.pending, "cannot nest flash loans"
        self.pending = True

        # deploy necessary contract and any other setup transactions
        self.setup()

        # save history
        self.old_history = network.history.copy()

        # snapshot here. so we can revert to before any non-atomic transactions are sent
        chain.snapshot()

        # clear history. everything in history at exit will be rolled into a single transaction
        network.history.clear()

        return self

    def ignore_tx(self, tx):
        self.ignore_txids.append(tx.txid)

    def __exit__(self, exc_type, value, traceback):
        print("Multiple transaction dry run complete!")

        if exc_type != None:
            # we got an exception
            return False

        self._atomic_transaction_from_history()

        self.pending = False
        self.ignore_txids.clear()

    def _atomic_transaction_from_history(self):
        # send atomic transaction (on forked network)
        assert web3.provider.endpoint_uri == self.host_fork, "oh no!"

        # build atomic transaction out of history
        print("Compiling atomic transcation...")
        flash_actions = []
        for tx in network.history:
            if tx.txid in self.ignore_txids:
                continue

            # TODO: logging

            # TODO: figure out delegate calls (code 0 instead of 1) and address replacement
            action = (tx.receiver, 1, tx.input)

            flash_actions.append(action)

        # reset history
        chain.revert()
        network.history = self.old_history

        # TODO: do this without a web3 call?
        flash_params = self.flash_borrower.encodeFlashParams(flash_actions)

        assets = []
        amounts = []
        modes = []
        for asset, amount in self.asset_amounts.items():
            assets.append(asset)
            amounts.append(amount)
            modes.append(0)

        self.flash_tx = self.aave_lender.flashLoan(
            self.clone, assets, amounts, modes, self.clone, flash_params, 0, {"from": self.owner}
        )
        self.flash_tx.info()

    def send_for_real(self):
        print("Sending the transaction for real!")
        assert self.flash_tx, "no pending transaction"

        # save history
        old_history = network.history.copy()

        # do some initial setup on public mainnet
        web3.provider.endpoint_uri = self.host_main

        # TODO: do something to make sure setup was already run?

        if self.host_private:
            # if set, send the atomic transaction from the private relay
            web3.provider.endpoint_uri = self.host_private

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
        web3.provider.endpoint_uri = self.host_fork

        network.history = old_history

        return tx
