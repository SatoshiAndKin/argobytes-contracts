import contextlib
from pprint import pformat

import click
from brownie import accounts, chain, network, rpc, web3
from brownie._config import CONFIG
from eth_utils.address import is_address

from argobytes.contracts import get_or_clone_flash_borrower, load_contract


class ArgobytesFlashManager:
    """
    Safely send flash loans.

    Extend this, calculate amounts and deploy conracts in __init__,
    override `the_transactions` function to do whatever you want,
    then call careful_send.

    TODO: be able to atomically do any trade, not just flash loans
    """

    def __init__(
        self,
        owner,
        aave_market_id=0,
        borrowed_assets=None,
        borrower_salt=None,
        clone_salt=None,
        delegate_callable=None,
        factory_salt=None,
        host_private="https://api.edennetwork.io/v1/rpc",
        sender=None,
        setup_transactions=None,
    ):
        active_network = CONFIG.active_network

        assert active_network["id"].endswith("-fork"), "must be on a forked network"

        forked_host = active_network["cmd_settings"]["fork"]
        assert forked_host.startswith("http"), "only http supported for now"

        self.owner = owner
        self.host_fork = web3.provider.endpoint_uri
        self.host_main = forked_host
        self.host_private = host_private
        self.borrower_salt = borrower_salt
        self.clone_salt = clone_salt
        self.factory_salt = factory_salt
        self.setup_transactions = setup_transactions or []

        if not sender:
            self.sender = owner
        else:
            self.sender = sender
            raise NotImplementedError("make sure auth is setup for this sender")

        # TODO: if host_private, make sure sender has at least 100 EDEN staked

        self.aave_provider_registry = load_contract("0x52D306e36E3B6B02c153d0266ff0f85d18BCD413")

        # #0 is main Aave V2 market. #1 is Aave AMM market
        self.aave_provider = load_contract(self.aave_provider_registry.getAddressesProvidersList()[aave_market_id])
        self.aave_lender = load_contract(self.aave_provider.getLendingPool())

        self.pending = False
        self.factory = self.flash_borrower = self.clone = self.flash_tx = None
        self.delegate_callable = [getattr(dc, "address", dc) for dc in delegate_callable or []]
        self.ignored = []

        self.borrowed_assets = borrowed_assets or {}
        self.lenders = {}
        for asset in self.borrowed_assets:
            reserve_data = self.aave_lender.getReserveData(asset)

            # unlock the reserve that we are going to be flash loaning from
            # TODO: If enough funds are in on the owner (or other accounts that have approved the clone), we should use those instead
            self.lenders[asset] = accounts.at(reserve_data[7], force=True)

    def __enter__(self):
        """Context manager that captures transactions for bundling."""
        print("Starting multi-transacation dry run!")

        assert not self.pending, "cannot nest flash loans"
        self.pending = True

        # ignore any transactions in the history before this
        # this could be more efficient, but this works for now
        self.ignored = list(range(0, len(network.history)))

        # snapshot here. so we can revert to before any non-atomic transactions are sent
        chain.snapshot()

        # send each asset to the clone just like the flash loan would
        # on a forked network, we transfer from the unlocked lender
        # on mainnet, this transfer is handled by the flash loan function
        # every flash loan MUST include at least one transfer of each asset in self.borrowed_assets to the clone
        for asset, amount in self.borrowed_assets.items():
            assert amount, f"No amount set for {asset}"
            print("Simulating flash loan of {amount:_} {asset}...")
            asset.transfer(self.clone, amount, {"from": self.lenders[asset]})

        return self

    def __exit__(self, exc_type, value, traceback):
        """Context manager that captures transactions for bundling."""
        print("Multiple transaction dry run complete!")

        if exc_type is not None:
            # we got an exception
            return False

        self.flash_tx = self._flashloan_from_history()

        self.pending = False

    @contextlib.contextmanager
    def ignore_transactions(self):
        # TODO: do we still need this?
        start_history_length = len(network.history)

        yield

        for i in range(start_history_length, len(network.history)):
            self.ignored.append(i)

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

    def careful_send(self, prompt_confirmation=True):
        """Do a dry run, prompt, send the transaction for real."""
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

        return self._mainnet_send(setup_did_something)

    def _mainnet_send(self, setup_did_something):
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

        self._send_for_real()

    def set_network_fork(self):
        if self.pending:
            raise RuntimeError

        if web3.provider.endpoint_uri == self.host_fork:
            return

        print("Setting network mode:", click.style("fork", fg="green"))
        web3.provider.endpoint_uri = self.host_fork

        # TODO: i'm no sure about this clear
        network.history.clear()

    def set_network_main(self):
        if self.pending:
            raise RuntimeError

        if web3.provider.endpoint_uri == self.host_main:
            return

        print("Setting network mode:", click.style("main", fg="red"))
        web3.provider.endpoint_uri = self.host_main

        network.history.clear()

    def set_network_private(self):
        if self.pending:
            raise RuntimeError

        if not self.host_private:
            print("Network mode private is disabled!")
            return self.set_network_main()

        if web3.provider.endpoint_uri == self.host_private:
            return

        print("Setting network mode:", click.style("private", fg="yellow"))
        web3.provider.endpoint_uri = self.host_private

        network.history.clear()

    def setup(self) -> int:
        start_history_len = len(network.history)

        # run any extra setup transactions
        for tx in self.setup_transactions:
            if not tx:
                continue

            # TODO: get the actual Contract for this so brownie's info is better?
            # TODO: if we set gas_limit and allow_revert=False, how does it check for revert?
            # TODO: are we suure required_confs=0 is always going to be okay?
            self.sender.transfer(
                to=tx.receiver,
                data=tx.input,
                gas_limit=tx.gas_limit,
                allow_revert=False,
                required_confs=0,
            )

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

        network.history.wait()

        return len(network.history) - start_history_len

    def the_transactions(self):
        """Send a bunch of transactions to be bundled into a flash loan."""
        raise NotImplementedError("proper abstract base class")

    def _actions_from_history(self):
        assert web3.provider.endpoint_uri == self.host_fork, "oh no!"

        # pull actions out of history
        asset_amounts = {}
        actions = []
        for i, tx in enumerate(network.history):
            if i in self.ignored:
                print(f"skipped tx: {tx.txid}")
                continue
            else:
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

            # TODO: do this in a more general way. hard coding special cases is really fragile
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

    def _send_for_real(self):
        print("Sending the transaction for real!")
        assert self.flash_tx, "no pending transaction"

        self.set_network_private()

        # send the transaction to be confirmed on the real chain
        # TODO: use the same gas estimate?
        tx = self.sender.transfer(
            to=self.flash_tx.receiver,
            data=self.flash_tx.input,
            gas_limit=self.flash_tx.gas_limit,
            allow_revert=False,
        )
        tx.info()

        # set the provide back to the forked network
        self.reset_network_fork()

        return tx
