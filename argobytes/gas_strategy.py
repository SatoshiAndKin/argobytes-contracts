from brownie import web3
from brownie.convert import Wei
from brownie.network.gas.bases import BlockGasStrategy
from enum import Enum
from typing import Generator, Optional


# TODO: class EIP1559GasStrategy

class GasSpeed(Enum):
    SLOW = 1
    NORMAL = 2
    FAST = 3
    RAPID = 4


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
    block_duration : int
        Number of blocks between transactions
    """
    def __init__(
        self,
        speed: GasSpeed,
        max_price: Optional[Wei] = None,
        block_duration: int = 3,
    ):
        # TODO: tune these
        if speed == GasSpeed.SLOW:
            initial_increment = 0.5,
        elif speed == GasSpeed.NORMAL:
            initial_increment = 0.8,
        elif speed == GasSpeed.FAST:
            initial_increment = 1.0,
        else: # speed == GasSpeed.RAPID
            initial_increment = 1.25,

        # TODO: different inccrements for different speeds?
        increment = 1.25
        if (increment < 1.1): 
            raise RuntimeError("increment too small")

        super().__init__(block_duration)
        self.max_gas_price = Wei(max_price)
        self.initial_increment = initial_increment
        self.increment = increment

    def get_gas_price(self) -> Generator[Wei, None, None]:
        last_gas_price = 0
        while True:
            # choose the larger of...
            next_price = max(
                # incrementing the last price
                Wei(last_gas_price * self.increment),
                # the price we would use if this were the first try
                Wei(web3.eth.gasPrice * self.initial_increment),
            )

            if self.max_gas_price:
                # but don't go higher than the max
                last_gas_price = min(next_price, self.max_gas_price)

            yield last_gas_price
