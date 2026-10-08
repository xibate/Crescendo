local _, ns = ...

--https://warcraft.wiki.gg/wiki/SpecializationID
ns.specs = {
    [1468] = "Preservation",
    [256] = "Discipline",
    [257] = "HolyPriest",
    [105] = "RestoDruid",
    [264] = "RestoShaman",
    [65] = "HolyPaladin"
}

--https://wago.tools/db2/DungeonEncounter
--The Venomous Abyss (Midnight Season 2). Encounter ids taken from BigWigs
--Phase triggers used combat log events, which addons can't read since Midnight, so phases are left empty.
--Phases now follow the stages reported by BigWigs or DBM, or /hrh phase <number> without a boss mod
--Midnight Season 1 raids, add them here to use the addon there: Imperator Averzian 3176, Vorasius 3177,
--Vaelgor & Ezzorak 3178, Fallen-King Salhadaar 3179, Lightblinded Vanguard 3180, Crown of the Cosmos 3181,
--Belo'ren, Child of Al'ar 3182, Midnight Falls 3183, Chimaerus the Undreamt God 3306
ns.bosses = {
    [3420] = {
        name = "Sszorak",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3421] = {
        name = "The Twin Fangs",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3429] = {
        name = "The Coiled Altar",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3445] = {
        name = "Entombed Sentinels",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3455] = {
        name = "Vashnik the Malignant",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3470] = {
        name = "Nek'zali the Soulcoiler",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3492] = {
        name = "Ula'tek",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    },
    [3497] = {
        name = "The Lost Explorers",
        phases = {
            ["myth"] = {},
            ["hero"] = {}
        }
    }
}

ns.difficulties = {
    [15] = {
        ["slug"] = "hero",
        ["name"] = "Heroic"
    },
    [16] = {
        ["slug"] = "myth",
        ["name"] = "Mythic"
    }
}

ns.phaseEvents = {
    ["SCC"] = "SPELL_CAST_SUCCESS",
    ["SCS"] = "SPELL_CAST_START",
    ["SAA"] = "SPELL_AURA_APPLIED",
    ["SAR"] = "SPELL_AURA_REMOVED",
}