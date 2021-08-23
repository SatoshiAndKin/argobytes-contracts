from enum import Enum
from typing import Generator, Optional

from brownie import web3
from brownie.convert import Wei
from brownie.network.gas.bases import BlockGasStrategy
from web3.gas_strategies.rpc import rpc_gas_price_strategy

# TODO: class EIP1559GasStrategy


class GasStrategyV1(BlockGasStrategy):
    """
    Gas strategy for linear gas price increases.

    This is for v1 (pre-EIP1559) transactions!

    TODO: i'd prefer to use a gas-now style strategy, but these chains don't have the graphql rpc necessary to do that

    Arguments
    ---------
    start_price
    speed : GasSpeed
    max_gas_price : Optional[Wei]
        The maximum gas price to use. This is a safety measure
    block_duration : int
        Number of blocks between transactions
    """

    def __init__(
        self,
        speed: str,
        max_price: Optional[Wei] = None,
        block_duration: int = 3,
    ):
        # TODO: tune these
        # TODO: enum
        if speed == "slow":
            initial_increment = 0.5
        elif speed == "standard":
            initial_increment = 0.8
        elif speed == "fast":
            initial_increment = 1.0
        elif speed == "rapid":
            initial_increment = 1.25
        else:
            raise RuntimeError

        # TODO: different inccrements for different speeds?
        increment = 1.25
        if increment < 1.1:
            raise RuntimeError("increment too small")

        super().__init__(block_duration)
        self.max_gas_price = Wei(max_price)
        self.speed = speed
        self.initial_increment = initial_increment
        self.increment = increment

    def __str__(self) -> str:
        gas_price = next(self.get_gas_price())
        return f"{self.speed} GasStrategyV1 recommends {gas_price/1e9} gwei"

    def get_gas_price(self) -> Generator[Wei, None, None]:
        last_gas_price = 0
        while True:
            start_price = Wei(rpc_gas_price_strategy(web3) * self.initial_increment)
            next_price = Wei(last_gas_price * self.increment)

            next_price = max(next_price, start_price)

            if self.max_gas_price:
                # but don't go higher than the max
                last_gas_price = min(next_price, self.max_gas_price)
            else:
                last_gas_price = next_price

            yield last_gas_price
