from enum import Enum
from typing import Generator, Optional

from brownie import web3
from brownie.convert import Wei
from brownie.network.gas.bases import TimeGasStrategy
from web3.gas_strategies.rpc import rpc_gas_price_strategy

# TODO: class EIP1559GasStrategy


# todo: i keep flip flopping between Time and Block strategy
# people care about seconds and not blocks, but transactions clear in blocks
# TODO: make a hybrid. take time, but divide by avg block time for the last 1000 blocks and use BlockGasStrategy
class GasStrategyV1(TimeGasStrategy):
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
        if speed == "slow":
            initial_increment = 0.5
            time_duration = 120
            max_multiplier = 1
        elif speed == "standard":
            initial_increment = 0.8
            time_duration = 50
            max_multiplier = 2
        elif speed == "fast":
            initial_increment = 1.2
            time_duration = 30
            max_multiplier = 3
        elif speed == "rapid":
            initial_increment = 1.5
            time_duration = 15
            max_multiplier = 10
        else:
            raise RuntimeError

        # TODO: different inccrements for different speeds?
        increment = 1.125
        if increment < 1.1:
            raise RuntimeError("increment too small")

        super().__init__(time_duration)
        self.max_gas_price = Wei(max_price)
        self.speed = speed
        self.initial_increment = initial_increment
        self.increment = increment
        self.max_multiplier = max_multiplier

    def __str__(self) -> str:
        gas_price = next(self.get_gas_price())
        return f"{self.speed} GasStrategyV1 recommends {gas_price/1e9} gwei"

    def get_gas_price(self) -> Generator[Wei, None, None]:
        last_gas_price = 0
        max_gas_price = self.max_gas_price
        while True:
            rpc_price = rpc_gas_price_strategy(web3)

            start_price = Wei(rpc_price * self.initial_increment)
            next_price = Wei(last_gas_price * self.increment)

            if start_price > next_price:
                # first run or gas price has risen on the network
                # reset our max price
                if not self.max_gas_price:
                    max_gas_price = rpc_price * self.max_multiplier
                print(f"current max gas price: {max_gas_price/1e9} gwei")

                next_price = start_price

            # don't go higher than the max
            last_gas_price = min(next_price, max_gas_price)

            yield last_gas_price
