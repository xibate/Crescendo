local _, ns = ...

--Raids and their bosses in journal order, by encounter id as BigWigs uses them. Generated from BigWigs' boss modules.
--Pulling a raid boss that isn't listed prints its encounter id in chat. collapsed: the raid starts folded in the planner
ns.raids = {
    { name = "The Venomous Abyss", bosses = {
        { encounterId = 3420, name = "Sszorak" },
        { encounterId = 3445, name = "Entombed Sentinels" },
        { encounterId = 3455, name = "Vashnik the Malignant" },
        { encounterId = 3429, name = "The Coiled Altar" },
        { encounterId = 3421, name = "The Twin Fangs" },
        { encounterId = 3470, name = "Nek'zali the Soulcoiler" },
        { encounterId = 3497, name = "The Lost Explorers" },
        { encounterId = 3492, name = "Ula'tek" }
    } },
    { name = "The Unbinding of Kith'ix", bosses = {
        { encounterId = 3513, name = "Kith'ix" }
    } },
    { name = "Midnight Lairs", bosses = {
        { encounterId = 3379, name = "Nymrissa Wavecaller" }
    } },
    { name = "The Voidspire", collapsed = true, bosses = {
        { encounterId = 3176, name = "Imperator Averzian" },
        { encounterId = 3177, name = "Vorasius" },
        { encounterId = 3178, name = "Vaelgor & Ezzorak" },
        { encounterId = 3179, name = "Fallen-King Salhadaar" },
        { encounterId = 3180, name = "Lightblinded Vanguard" },
        { encounterId = 3181, name = "Crown of the Cosmos" }
    } },
    { name = "The Dreamrift", collapsed = true, bosses = {
        { encounterId = 3306, name = "Chimaerus the Undreamt God" }
    } },
    { name = "March on Quel'Danas", collapsed = true, bosses = {
        { encounterId = 3182, name = "Belo'ren, Child of Al'ar" },
        { encounterId = 3183, name = "Midnight Falls" }
    } }
}

--Bosses by encounter id: { name, raid = the raid's name, order = its place in the raid list }
ns.bosses = {}
for _, raid in ipairs(ns.raids) do
    for order, boss in ipairs(raid.bosses) do
        ns.bosses[boss.encounterId] = { name = boss.name, raid = raid.name, order = order }
    end
end

ns.difficulties = {
    [15] = { slug = "hero", name = "Heroic" },
    [16] = { slug = "myth", name = "Mythic" }
}

--Other difficulty ids that use the plans of one of the above: 233 is Mythic - Flexible Raiding
ns.difficultyAliases = { [233] = 16 }
