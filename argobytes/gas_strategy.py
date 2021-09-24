import time
from typing import Generator, Optional

import requests
from brownie import chain
from brownie.convert import Wei
from brownie.network.gas.bases import BlockGasStrategy
from toolz.itertoolz import last

from argobytes.replay import get_upstream_rpc, is_forked_network

# TODO: class EIP1559GasStrategy


# todo: i keep flip flopping between Time and Block strategy
# people care about seconds and not blocks, but transactions clear in blocks
# TODO: make a hybrid. take time, but divide by avg block time for the last 1000 blocks and use BlockGasStrategy
class GasStrategyV1(BlockGasStrategy):
    """
    Gas strategy for linear gas price increases.

    This is for v1 (pre-EIP1559) transactions!

    TODO: i'd prefer to use a gas-now style strategy, but these chains don't have the graphql rpc necessary to do that

    Arguments
    ---------
    speed : GasSpeed
    max_gas_price : Optional[Wei]
        The maximum gas price to use. This is a safety measure
    """

    def __init__(
        self,
        speed: str,
        max_price: Optional[Wei] = None,
    ):
        # TODO: tune these. need to think about max_multipliers and incrementss and how long these take to hit their maxes
        # TODO: enum
        # TODO: this is not a good strategy. the recommendations from the node are not good
        if speed == "slow":
            initial_increment = 0.75
            time_duration = 60
            max_multiplier = 1.1
        elif speed == "standard":
            initial_increment = 1.0
            time_duration = 30
            max_multiplier = 2
        elif speed == "fast":
            initial_increment = 1.2
            time_duration = 20
            max_multiplier = 3
        elif speed == "rapid":
            # have rapid increment faster, too? add a random jitter?
            initial_increment = 1.5
            time_duration = 10
            max_multiplier = 4
        else:
            raise RuntimeError

        # TODO: different inccrements for different speeds?
        increment = 1.125
        if increment < 1.1:
            raise RuntimeError("increment too small. nodes will reject this increase")

        if chain.id == 137 and is_forked_network():
            # TODO: something is broken with ganache+polygon+parsing blocks
            # their error message sends us here:
            # http://web3py.readthedocs.io/en/stable/middleware.html#geth-style-proof-of-authority
            block_time = 2.4
        else:
            block_time = (time.time() - chain[-1000].timestamp) / 1000

        block_duration = int(round(time_duration / block_time, 0))
        if not block_duration:
            block_duration = 1

        super().__init__(block_duration)
        self.max_gas_price = Wei(max_price)
        self.speed = speed
        self.initial_increment = initial_increment
        self.increment = increment
        self.max_multiplier = max_multiplier

        self.rpc_for_gas = get_upstream_rpc()

    def __str__(self) -> str:
        gas_price = next(self.get_gas_price())
        return f"{self.speed} GasStrategyV1 recommends {gas_price/1e9:_} gwei (increasing after {self.duration} blocks)"

    def get_base_gas_price(self) -> Wei:
        """
        Get the recommended gas price from the upstream node.

        Ganache-cli gives a static gas price, so we don't want to query it.

        I would much rather use a gas-now style prediction based on speed for this.
        """
        if chain.id == 137:
            # polygon's eth_gasPrice always tells us 1 even though it needs to be higher. the average is like 30
            # TODO: different based on speed?
            # hard code 25 gwei for now
            return 25e9

        # we use requests instead of web3 because this might be a different rpc server
        r = requests.post(
            self.rpc_for_gas,
            json={
                "jsonrpc": "2.0",
                "method": "eth_gasPrice",
                "params": [],
                "id": 1,
            },
        )
        r = r.json()
        return int(r["result"], 16)

    def get_gas_price(self) -> Generator[Wei, None, None]:
        # just in case we changed networks
        self.rpc_for_gas = get_upstream_rpc()

        max_gas_price = self.max_gas_price
        last_gas_price = 0
        while True:
            base_price = self.get_base_gas_price()

            start_price = Wei(base_price * self.initial_increment)
            next_price = Wei(last_gas_price * self.increment)

            if start_price > next_price:
                # first run or gas price has risen on the network
                if not self.max_gas_price:
                    # no overall max price is set. set our max price based on the price recommended to us
                    max_gas_price = base_price * self.max_multiplier
                print(f"Current max gas price: {max_gas_price/1e9:_} gwei")

                next_price = start_price

            # don't go higher than the max
            last_gas_price = min(next_price, max_gas_price)

            yield last_gas_price


class GasStrategyMinimum(BlockGasStrategy):
    """
    Gas strategy for paying minimum possible gas. This will be very slow on congested chains.

    TODO: i'd prefer to use a gas-now style strategy, but these chains don't have the graphql rpc necessary to do that
    """

    def __init__(
        self,
        time_duration = 60,
        extra = "1 gwei"
    ):
        if chain.id == 137 and is_forked_network():
            # TODO: something is broken with ganache+polygon+parsing blocks
            # their error message sends us here:
            # http://web3py.readthedocs.io/en/stable/middleware.html#geth-style-proof-of-authority
            block_time = 2.4
        else:
            block_time = (time.time() - chain[-1000].timestamp) / 1000

        block_duration = int(round(time_duration / block_time, 0))
        if not block_duration:
            block_duration = 1

        super().__init__(block_duration)

        self.extra = extra

    def __str__(self) -> str:
        gas_price = next(self.get_gas_price())
        return f"GasStrategyMinimum recommends {gas_price/1e9:_} gwei (checking after {self.duration} blocks)"

    def get_minimum_gas_price(self) -> int:
        if "minimumGasPrice" in chain[-1]:
            return chain[-1]["minimumGasPrice"]

        raise NotImplementedError

    def get_gas_price(self) -> Generator[Wei, None, None]:
        last_gas_price = self.get_minimum_gas_price()

        yield last_gas_price

        while True:
            min_price = self.get_minimum_gas_price()

            last_gas_price = last_gas_price * 1.101

            last_gas_price = min(min_price, last_gas_price)

            # this might not broadcast if too close to the previous price
            yield last_gas_price
