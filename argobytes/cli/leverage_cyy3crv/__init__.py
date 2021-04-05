import click

from .atomic_enter import atomic_enter
from .atomic_exit import atomic_exit
from .simple_enter import simple_enter
from .simple_exit import simple_exit


@click.group()
def leverage_cyy3crv():
    """DAI <-> 3crv <-> y3crv <-> cyy3crv <-> DAI."""


leverage_cyy3crv.add_command(atomic_enter)
leverage_cyy3crv.add_command(atomic_exit)
leverage_cyy3crv.add_command(simple_enter)
leverage_cyy3crv.add_command(simple_exit)
