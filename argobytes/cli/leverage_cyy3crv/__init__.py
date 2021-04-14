import click

from argobytes.cli_helpers_lite import CommandWithAccount


@click.group()
def leverage_cyy3crv():
    """DAI <-> 3crv <-> y3crv <-> cyy3crv <-> DAI."""


@leverage_cyy3crv.command(cls=CommandWithAccount)
@click.option("--min-3crv-to-claim", default=50, show_default=True)
def atomic_enter(account, min_3crv_to_claim):
    from .atomic_enter import atomic_enter

    atomic_enter(account, min_3crv_to_claim)


@click.command(cls=CommandWithAccount)
@click.option("--tip-eth", default=0)
@click.option("--tip-3crv", default=0)
def atomic_exit(account, tip_eth, tip_3crv):
    from .atomic_exit import atomic_exit

    atomic_exit(account, tip_eth, tip_3crv)


@click.command(cls=CommandWithAccount)
def simple_enter(account):
    from .simple_enter import simple_enter

    simple_enter(account)


@click.command(cls=CommandWithAccount)
def simple_exit(account):
    from .simple_exit import simple_exit

    simple_exit(account)
