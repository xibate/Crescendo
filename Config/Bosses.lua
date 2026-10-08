local _, ns = ...

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
