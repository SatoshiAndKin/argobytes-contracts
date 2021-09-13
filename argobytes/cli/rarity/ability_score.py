# see arrays.html
import itertools
import random
from collections import namedtuple
from enum import IntEnum
from itertools import permutations
from typing import DefaultDict

from .rarity_logic import RarityBaseClass

# TODO: calculate this in python instead of misc/rarity-point-buy/arrays.html
all_attribute_permutations = [
    (22,8,8,8,8,8),
    (21,12,8,8,8,8),
    (21,11,9,8,8,8),
    (21,10,10,8,8,8),
    (21,10,9,9,8,8),
    (21,9,9,9,9,8),
    (20,15,8,8,8,8),
    (20,14,10,8,8,8),
    (20,14,9,9,8,8),
    (20,13,11,8,8,8),
    (20,13,10,9,8,8),
    (20,13,9,9,9,8),
    (20,12,12,8,8,8),
    (20,12,11,9,8,8),
    (20,12,10,10,8,8),
    (20,12,10,9,9,8),
    (20,12,9,9,9,9),
    (20,11,11,10,8,8),
    (20,11,11,9,9,8),
    (20,11,10,10,9,8),
    (20,11,10,9,9,9),
    (20,10,10,10,10,8),
    (20,10,10,10,9,9),
    (19,16,10,8,8,8),
    (19,16,9,9,8,8),
    (19,15,12,8,8,8),
    (19,15,11,9,8,8),
    (19,15,10,10,8,8),
    (19,15,10,9,9,8),
    (19,15,9,9,9,9),
    (19,14,14,8,8,8),
    (19,14,13,9,8,8),
    (19,14,12,10,8,8),
    (19,14,12,9,9,8),
    (19,14,11,11,8,8),
    (19,14,11,10,9,8),
    (19,14,11,9,9,9),
    (19,14,10,10,10,8),
    (19,14,10,10,9,9),
    (19,13,13,10,8,8),
    (19,13,13,9,9,8),
    (19,13,12,11,8,8),
    (19,13,12,10,9,8),
    (19,13,12,9,9,9),
    (19,13,11,11,9,8),
    (19,13,11,10,10,8),
    (19,13,11,10,9,9),
    (19,13,10,10,10,9),
    (19,12,12,12,8,8),
    (19,12,12,11,9,8),
    (19,12,12,10,10,8),
    (19,12,12,10,9,9),
    (19,12,11,11,10,8),
    (19,12,11,11,9,9),
    (19,12,11,10,10,9),
    (19,12,10,10,10,10),
    (19,11,11,11,11,8),
    (19,11,11,11,10,9),
    (19,11,11,10,10,10),
    (18,18,8,8,8,8),
    (18,17,11,8,8,8),
    (18,17,10,9,8,8),
    (18,17,9,9,9,8),
    (18,16,14,8,8,8),
    (18,16,13,9,8,8),
    (18,16,12,10,8,8),
    (18,16,12,9,9,8),
    (18,16,11,11,8,8),
    (18,16,11,10,9,8),
    (18,16,11,9,9,9),
    (18,16,10,10,10,8),
    (18,16,10,10,9,9),
    (18,15,15,8,8,8),
    (18,15,14,10,8,8),
    (18,15,14,9,9,8),
    (18,15,13,11,8,8),
    (18,15,13,10,9,8),
    (18,15,13,9,9,9),
    (18,15,12,12,8,8),
    (18,15,12,11,9,8),
    (18,15,12,10,10,8),
    (18,15,12,10,9,9),
    (18,15,11,11,10,8),
    (18,15,11,11,9,9),
    (18,15,11,10,10,9),
    (18,15,10,10,10,10),
    (18,14,14,12,8,8),
    (18,14,14,11,9,8),
    (18,14,14,10,10,8),
    (18,14,14,10,9,9),
    (18,14,13,13,8,8),
    (18,14,13,12,9,8),
    (18,14,13,11,10,8),
    (18,14,13,11,9,9),
    (18,14,13,10,10,9),
    (18,14,12,12,10,8),
    (18,14,12,12,9,9),
    (18,14,12,11,11,8),
    (18,14,12,11,10,9),
    (18,14,12,10,10,10),
    (18,14,11,11,11,9),
    (18,14,11,11,10,10),
    (18,13,13,13,9,8),
    (18,13,13,12,10,8),
    (18,13,13,12,9,9),
    (18,13,13,11,11,8),
    (18,13,13,11,10,9),
    (18,13,13,10,10,10),
    (18,13,12,12,11,8),
    (18,13,12,12,10,9),
    (18,13,12,11,11,9),
    (18,13,12,11,10,10),
    (18,13,11,11,11,10),
    (18,12,12,12,12,8),
    (18,12,12,12,11,9),
    (18,12,12,12,10,10),
    (18,12,12,11,11,10),
    (18,12,11,11,11,11),
    (17,17,14,8,8,8),
    (17,17,13,9,8,8),
    (17,17,12,10,8,8),
    (17,17,12,9,9,8),
    (17,17,11,11,8,8),
    (17,17,11,10,9,8),
    (17,17,11,9,9,9),
    (17,17,10,10,10,8),
    (17,17,10,10,9,9),
    (17,16,15,9,8,8),
    (17,16,14,11,8,8),
    (17,16,14,10,9,8),
    (17,16,14,9,9,9),
    (17,16,13,12,8,8),
    (17,16,13,11,9,8),
    (17,16,13,10,10,8),
    (17,16,13,10,9,9),
    (17,16,12,12,9,8),
    (17,16,12,11,10,8),
    (17,16,12,11,9,9),
    (17,16,12,10,10,9),
    (17,16,11,11,11,8),
    (17,16,11,11,10,9),
    (17,16,11,10,10,10),
    (17,15,15,11,8,8),
    (17,15,15,10,9,8),
    (17,15,15,9,9,9),
    (17,15,14,13,8,8),
    (17,15,14,12,9,8),
    (17,15,14,11,10,8),
    (17,15,14,11,9,9),
    (17,15,14,10,10,9),
    (17,15,13,13,9,8),
    (17,15,13,12,10,8),
    (17,15,13,12,9,9),
    (17,15,13,11,11,8),
    (17,15,13,11,10,9),
    (17,15,13,10,10,10),
    (17,15,12,12,11,8),
    (17,15,12,12,10,9),
    (17,15,12,11,11,9),
    (17,15,12,11,10,10),
    (17,15,11,11,11,10),
    (17,14,14,14,9,8),
    (17,14,14,13,10,8),
    (17,14,14,13,9,9),
    (17,14,14,12,11,8),
    (17,14,14,12,10,9),
    (17,14,14,11,11,9),
    (17,14,14,11,10,10),
    (17,14,13,13,11,8),
    (17,14,13,13,10,9),
    (17,14,13,12,12,8),
    (17,14,13,12,11,9),
    (17,14,13,12,10,10),
    (17,14,13,11,11,10),
    (17,14,12,12,12,9),
    (17,14,12,12,11,10),
    (17,14,12,11,11,11),
    (17,13,13,13,12,8),
    (17,13,13,13,11,9),
    (17,13,13,13,10,10),
    (17,13,13,12,12,9),
    (17,13,13,12,11,10),
    (17,13,13,11,11,11),
    (17,13,12,12,12,10),
    (17,13,12,12,11,11),
    (17,12,12,12,12,11),
    (16,16,16,10,8,8),
    (16,16,16,9,9,8),
    (16,16,15,12,8,8),
    (16,16,15,11,9,8),
    (16,16,15,10,10,8),
    (16,16,15,10,9,9),
    (16,16,14,14,8,8),
    (16,16,14,13,9,8),
    (16,16,14,12,10,8),
    (16,16,14,12,9,9),
    (16,16,14,11,11,8),
    (16,16,14,11,10,9),
    (16,16,14,10,10,10),
    (16,16,13,13,10,8),
    (16,16,13,13,9,9),
    (16,16,13,12,11,8),
    (16,16,13,12,10,9),
    (16,16,13,11,11,9),
    (16,16,13,11,10,10),
    (16,16,12,12,12,8),
    (16,16,12,12,11,9),
    (16,16,12,12,10,10),
    (16,16,12,11,11,10),
    (16,16,11,11,11,11),
    (16,15,15,14,8,8),
    (16,15,15,13,9,8),
    (16,15,15,12,10,8),
    (16,15,15,12,9,9),
    (16,15,15,11,11,8),
    (16,15,15,11,10,9),
    (16,15,15,10,10,10),
    (16,15,14,14,10,8),
    (16,15,14,14,9,9),
    (16,15,14,13,11,8),
    (16,15,14,13,10,9),
    (16,15,14,12,12,8),
    (16,15,14,12,11,9),
    (16,15,14,12,10,10),
    (16,15,14,11,11,10),
    (16,15,13,13,12,8),
    (16,15,13,13,11,9),
    (16,15,13,13,10,10),
    (16,15,13,12,12,9),
    (16,15,13,12,11,10),
    (16,15,13,11,11,11),
    (16,15,12,12,12,10),
    (16,15,12,12,11,11),
    (16,14,14,14,12,8),
    (16,14,14,14,11,9),
    (16,14,14,14,10,10),
    (16,14,14,13,13,8),
    (16,14,14,13,12,9),
    (16,14,14,13,11,10),
    (16,14,14,12,12,10),
    (16,14,14,12,11,11),
    (16,14,13,13,13,9),
    (16,14,13,13,12,10),
    (16,14,13,13,11,11),
    (16,14,13,12,12,11),
    (16,14,12,12,12,12),
    (16,13,13,13,13,10),
    (16,13,13,13,12,11),
    (16,13,13,12,12,12),
    (15,15,15,15,8,8),
    (15,15,15,14,10,8),
    (15,15,15,14,9,9),
    (15,15,15,13,11,8),
    (15,15,15,13,10,9),
    (15,15,15,12,12,8),
    (15,15,15,12,11,9),
    (15,15,15,12,10,10),
    (15,15,15,11,11,10),
    (15,15,14,14,12,8),
    (15,15,14,14,11,9),
    (15,15,14,14,10,10),
    (15,15,14,13,13,8),
    (15,15,14,13,12,9),
    (15,15,14,13,11,10),
    (15,15,14,12,12,10),
    (15,15,14,12,11,11),
    (15,15,13,13,13,9),
    (15,15,13,13,12,10),
    (15,15,13,13,11,11),
    (15,15,13,12,12,11),
    (15,15,12,12,12,12),
    (15,14,14,14,14,8),
    (15,14,14,14,13,9),
    (15,14,14,14,12,10),
    (15,14,14,14,11,11),
    (15,14,14,13,13,10),
    (15,14,14,13,12,11),
    (15,14,14,12,12,12),
    (15,14,13,13,13,11),
    (15,14,13,13,12,12),
    (15,13,13,13,13,12),
    (14,14,14,14,14,10),
    (14,14,14,14,13,11),
    (14,14,14,14,12,12),
    (14,14,14,13,13,12),
    (14,14,13,13,13,13),
]


class Ability(IntEnum):
    STR = 1
    DEX = 2
    CON = 3
    INT = 4
    WIS = 5
    CHA = 6


MIN_MIN_DUMP_STATS = 0
MAX_MAX_DUMP_STATS = 4
# TODO: range on this? sometimes 2 or 3 odds can be good (racial ability mods and magic items)
MAX_ODD_SCORES = 1

AttributeBounds = namedtuple("AbilityBounds", ["min_dump_stats", "max_dump_stats", "ability_rankings"])


ability_orders = {
    RarityBaseClass.BARBARIAN: [
        [
            # tier 1
            (
                Ability.STR,
                Ability.CON,
            ),
            # tier 2
            (
                Ability.DEX,  # TODO: need a str/con barb for now, but DEX is sometimes tier 1
                Ability.CHA,
                Ability.WIS,
            ),
            # tier 3
            (Ability.INT,),
        ]
    ],
    RarityBaseClass.BARD: [
        [
            # tier 1
            (Ability.CHA,),
            # tier 2
            (Ability.DEX,),
            # tier 3
            (Ability.CON,),
            # tier 4
            (
                Ability.INT,
                Ability.WIS,
                Ability.STR,
            ),
        ]
    ],
    RarityBaseClass.CLERIC: [
        [
            # tier 1
            (Ability.WIS,),
            # tier 2
            (Ability.STR,),
            # tier 3
            (Ability.CON,),
            # tier 4
            (Ability.CHA,),
            # tier 5
            (Ability.DEX,),
            # tier 6
            (Ability.INT,),
        ],
        [
            # tier 1
            (Ability.WIS,),
            # tier 2
            (Ability.DEX,),
            # tier 3
            (Ability.CON,),
            # tier 4
            (Ability.CHA,),
            # tier 5
            (Ability.STR,),
            # tier 6
            (Ability.INT,),
        ],
    ],
    RarityBaseClass.DRUID: [
        [
            # tier 1
            (
                Ability.WIS,
                Ability.DEX,
                Ability.CON,
            ),
            # tier 2
            (Ability.CHA,),
            # tier 3
            (Ability.INT,),
            # tier 4
            (Ability.STR,),
        ]
    ],
    RarityBaseClass.FIGHTER: [
        [
            # tier 1
            (Ability.STR,),
            # tier 2
            (Ability.CON,),
            # tier 3
            (Ability.DEX,),
            # tier 4
            (
                Ability.INT,
                Ability.WIS,
                Ability.CHA,
            ),
        ],
        [
            # tier 1
            (Ability.DEX,),
            # tier 2
            (Ability.CON,),
            # tier 3
            (Ability.STR,),
            # tier 4
            (
                Ability.INT,
                Ability.WIS,
                Ability.CHA,
            ),
        ],
    ],
    RarityBaseClass.MONK: [
        [
            # tier 1
            (Ability.DEX,),
            # tier 2
            (Ability.WIS,),
            # tier 3
            (
                Ability.CON,
                Ability.CHA,
            ),
            # tier 4
            (
                Ability.INT,
                Ability.STR,
            ),
        ],
        [
            # tier 1
            (Ability.DEX,),
            # tier 2
            (Ability.WIS,),
            # tier 3
            (
                Ability.CON,
                Ability.STR,
            ),
            # tier 4
            (
                Ability.INT,
                Ability.CHA,
            ),
        ],
    ],
    RarityBaseClass.PALADIN: [
        [
            # tier 1
            (
                Ability.STR,
                Ability.CON,
            ),
            # tier 2
            (Ability.CHA,),
            # tier 3
            (Ability.DEX,),
            # tier 4
            (
                Ability.WIS,
                Ability.INT,
            ),
        ]
    ],
    RarityBaseClass.RANGER: [
        [
            # tier 1
            (Ability.DEX,),
            # tier 2
            (Ability.WIS,),
            # tier 3
            (Ability.CON,),
            # tier 4
            (Ability.CHA,),
            # tier 5
            (Ability.INT,),
            # tier 6
            (Ability.STR,),
        ]
    ],
    RarityBaseClass.ROGUE: [
        [
            # tier 1
            (
                Ability.INT,
                Ability.DEX,
            ),
            # tier 2
            (
                Ability.CON,
                Ability.WIS,
                Ability.CHA,
                Ability.STR,
            ),
        ],
        [
            # tier 1
            (Ability.DEX,),
            # tier 2
            (Ability.STR,),
            # tier 3
            (
                Ability.CON,
                Ability.CHA,
            ),
            # tier 5
            (
                Ability.WIS,
                Ability.INT,
            ),
        ],
        [
            # tier 1
            (Ability.DEX,),
            # tier 2
            (Ability.INT,),
            # tier 3
            (Ability.CON,),
            # tier 4
            (Ability.CHA,),
            # tier 5
            (
                Ability.WIS,
                Ability.STR,
            ),
        ],
    ],
    RarityBaseClass.SORCERER: [
        [
            # tier 1
            (Ability.CHA,),
            # tier 2
            (
                Ability.DEX,
                Ability.CON,
                Ability.WIS,
                Ability.INT,
            ),
            # tier 3
            (Ability.STR,),
        ]
    ],
    RarityBaseClass.WIZARD: [
        [
            # tier 1
            (Ability.INT,),
            # tier 2
            (Ability.DEX, Ability.CON, Ability.WIS, Ability.CHA),
            # tier 3
            (Ability.STR,),
        ]
    ],
}

specialized = {"Market LP": NotImplemented, "Craft I Farmer": NotImplemented, "Craftsman I": NotImplemented}


def ability_score_modifier(score):
    return (score - 10) // 2


def array_rank(array, dump_stats):
    # if 2 or more odds, ignore
    num_odds = len([score for score in array if score % 2 == 1])
    if num_odds > MAX_ODD_SCORES:
        return None

    modifiers = [ability_score_modifier(score) for score in array]

    num_dump = len([mod for mod in modifiers if mod < 0])
    if num_dump != dump_stats:
        # if we pick a high dump stats to specialize, we dont want general arrays returned even if they have an equal score
        return None

    # ignore the negative values on our rank
    while num_dump and modifiers[-1] < 0:
        modifiers.pop()
        num_dump -= 1

    return sum(modifiers)


def rank_ability_permutations(dump_stats=0):
    ranked = DefaultDict(list)

    for array in all_attribute_permutations:
        rank = array_rank(array, dump_stats)

        if rank is None:
            continue

        ranked[rank].append(array)

    # sort the dict
    return {k: v for k, v in sorted(ranked.items(), key=lambda item: item[1], reverse=True)}


def _merge_tiers(tier_index: int, tiers):
    for tier in tiers[tier_index]:
        if tier_index + 1 == len(tiers):
            # we got to the end
            yield tier
        else:
            for next_tier in _merge_tiers(tier_index + 1, tiers):
                yield tier + next_tier


def get_ability_orders(classId: RarityBaseClass):
    possibilities = set()

    for order in ability_orders[classId]:
        x = [list(permutations(tier)) for tier in order]

        possibilities.update(_merge_tiers(0, x))

    return list(possibilities)


def get_random_scores(classId: RarityBaseClass):
    ability_order = random.choice(get_ability_orders(classId))

    # print("ability_order:", ability_order)

    # TODO: get this based on the class
    min_dump_stats = 1
    max_dump_stats = 3

    # TODO: get a stat with exaclty this amount of dump stats instead of at most.
    dump_stats = random.randint(min_dump_stats, max_dump_stats)
    print("max dump_stats:", dump_stats)

    ranked_scores = rank_ability_permutations(dump_stats=dump_stats)

    rank = random.choice(list(ranked_scores.keys()))
    print("sum of modifiers (excluding dump stats):", rank)

    ability_scores = random.choice(ranked_scores[rank])

    # TODO: return as a list?
    return {a: s for (a, s) in zip(ability_order, ability_scores)}
