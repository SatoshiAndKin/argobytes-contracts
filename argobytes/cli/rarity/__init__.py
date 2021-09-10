import click

from argobytes.cli_helpers_lite import CommandWithAccount


@click.group()
@click.pass_context
def rarity(ctx):
    """On-chain D&D"""
    # TODO: put this back on forked network and use dry runs
    ctx.obj["default_brownie_network"] = "ftm-main"


# TODO: CommandWithProxySalts
@rarity.command(cls=CommandWithAccount)
# TODO: option to run once or run until stopped
def adventure(account):
    """Adventure with all of your characters."""
    import time

    from brownie import chain
    from click_spinner import spinner

    from .rarity_logic import adventure

    # TODO: this while loop might be somewhat common. move it to a helper?
    while True:
        # try:
        next_run = adventure(account)
        # except Exception as exc:
        #     print("WARNING!", exc)
        #     next_run = None

        now = chain[-1].timestamp

        if next_run:
            sleep_seconds = next_run - now
            sleep_seconds += 60
        else:
            sleep_seconds = 10

        if sleep_seconds > 0:
            print(f"Sleeping {sleep_seconds} seconds...")
            with spinner():
                time.sleep(sleep_seconds)
        else:
            print("No sleep till Brooklyn")


@rarity.command(cls=CommandWithAccount)
def console(account):
    """Adventure with all of your"""
    from argobytes.cli_helpers import debug_shell

    from .rarity_logic import RARITY, ArgobytesBrownieProject, get_or_create, get_summoners

    rarity_action_v1 = get_or_create(account, ArgobytesBrownieProject.RarityActionV1)

    # TODO: load all the account's current summons
    debug_shell(
        {
            "account": account,
            "rarity": RARITY,
            "rarity_action_v1": rarity_action_v1,
            "summoners": get_summoners(account),
        }
    )


@rarity.command(cls=CommandWithAccount)
@click.argument("class_id", type=int)
@click.argument("amount", type=int, default=1)
@click.option("--adventure/--no-adventure", default=True)
def summon(account, class_id, amount, adventure):
    from .rarity_logic import summon

    summon(account, class_id, amount, adventure)


@rarity.command(cls=CommandWithAccount)
@click.argument("name", type=str)
def build_town(account, name):
    from .rarity_logic import build_town

    build_town(account, name)
