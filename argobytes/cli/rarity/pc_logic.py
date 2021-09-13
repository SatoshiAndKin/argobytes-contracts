from .rarity_logic import RARITY, RARITY_CRAFT_1, RARITY_GOLD, get_summoners


def summon(account, classId):
    tx = RARITY.summon(classId).info()

    summoner = tx["events"]["summoned"]["summoner"]

    print("new summoner:", summoner)

    # TODO: setup 


def adventure(account):
    for summoner in get_summoners(account):
        try:
            RARITY.adventure(summoner).info()
        except Exception:
                pass

        try:
            if RARITY_CRAFT_1.scout(summoner) > 0:
                # we could check adventure_log here, but just catching the exception is easier. we won't broadcast
                RARITY_CRAFT_1.adventure(summoner).info()
        except Exception:
            pass


# don't level up if you need the xp for something else!
def level_up(account):
    for summoner in get_summoners(account):
        level = RARITY.level(summoner)
        xp_required = RARITY.xp_required(level)
        xp = RARITY.xp(summoner)

        if xp_required >= xp:
            RARITY.level_up(summoner)

        if RARITY_GOLD.claimable(summoner) > 0:
            RARITY_GOLD.claim(summoner)


def craft():
    raise NotImplementedError
