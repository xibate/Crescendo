local _, ns = ...

--Spec data is filled in by the files in Config/Specs, keyed by the spec names below. Each spec has:
-- spells     spells the ramps are timed around: base cd in seconds, haste = true when haste shortens it,
--            talents = { [talent spell id] = seconds added to the cd }, charges = true for charged spells
-- cooldowns  spell id => name, every cooldown gets a 'Soon' countdown and a reminder at its time
-- utilities  spell id => name, same as cooldowns
-- ramps      spell id => ramp name, the ids MRT notes use for each ramp
-- rampSteps  function(cd) returning the steps of each ramp, cd(spellId) gives the current cooldown of a spell.
--            A step is { text, icon, offset = seconds before the ramp time, tts = spoken text instead of text,
--            prerequisite = true for setup steps, countdown = true to show a countdown,
--            chargesOf = spell id to remind once that spell's charges need all the time left to come back }
ns.specData = {}

--https://warcraft.wiki.gg/wiki/SpecializationID
ns.specs = {
    [1468] = "Preservation",
    [256] = "Discipline",
    [257] = "HolyPriest",
    [105] = "RestoDruid",
    [264] = "RestoShaman",
    [65] = "HolyPaladin"
}

--Encounter ids of the current raid, The Venomous Abyss (Midnight Season 2), as used by BigWigs.
--Pulling a raid boss that isn't listed prints its encounter id in chat.
--Midnight Season 1: Imperator Averzian 3176, Vorasius 3177, Vaelgor & Ezzorak 3178, Fallen-King Salhadaar 3179,
--Lightblinded Vanguard 3180, Crown of the Cosmos 3181, Belo'ren, Child of Al'ar 3182, Midnight Falls 3183,
--Chimaerus the Undreamt God 3306
ns.bosses = {
    [3420] = { name = "Sszorak" },
    [3421] = { name = "The Twin Fangs" },
    [3429] = { name = "The Coiled Altar" },
    [3445] = { name = "Entombed Sentinels" },
    [3455] = { name = "Vashnik the Malignant" },
    [3470] = { name = "Nek'zali the Soulcoiler" },
    [3492] = { name = "Ula'tek" },
    [3497] = { name = "The Lost Explorers" }
}

ns.difficulties = {
    [15] = { slug = "hero", name = "Heroic" },
    [16] = { slug = "myth", name = "Mythic" }
}
