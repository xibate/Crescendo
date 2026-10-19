local _, ns = ...

--Raids and their bosses in journal order, by encounter id as BigWigs uses them. Generated from BigWigs' boss modules.
--Pulling a raid boss that isn't listed prints its encounter id in chat. collapsed: the raid starts folded in the planner.
--instanceId is the raid's instance, journalId the boss's encounter journal id and npcs the creatures that are the boss
ns.raids = {
    { name = "The Venomous Abyss", instanceId = 3004, bosses = {
        { encounterId = 3420, name = "Sszorak", journalId = 2871, npcs = { 257347 } },
        { encounterId = 3445, name = "Entombed Sentinels", journalId = 2874, npcs = { 258557, 258556 } },
        { encounterId = 3455, name = "Vashnik the Malignant", journalId = 2882, npcs = { 259181 } },
        { encounterId = 3429, name = "The Coiled Altar", journalId = 2883, npcs = { 257911, 259854 } },
        { encounterId = 3421, name = "The Twin Fangs", journalId = 2887, npcs = { 257361, 257368 } },
        { encounterId = 3470, name = "Nek'zali the Soulcoiler", journalId = 2888, npcs = { 259927, 263050 } },
        { encounterId = 3497, name = "The Lost Explorers", journalId = 2894, npcs = { 261835, 261843, 261848 } },
        { encounterId = 3492, name = "Ula'tek", journalId = 2895, npcs = { 257758 } }
    } },
    { name = "The Unbinding of Kith'ix", instanceId = 3095, bosses = {
        { encounterId = 3513, name = "Kith'ix", journalId = 2896, npcs = { 267861 } }
    } },
    { name = "Midnight Lairs", instanceId = 2987, bosses = {
        { encounterId = 3379, name = "Nymrissa Wavecaller", journalId = 2849, npcs = { 252959 } }
    } },
    { name = "The Voidspire", instanceId = 2912, collapsed = true, bosses = {
        { encounterId = 3176, name = "Imperator Averzian", journalId = 2733, npcs = { 240435 } },
        { encounterId = 3177, name = "Vorasius", journalId = 2734, npcs = { 240434 } },
        { encounterId = 3178, name = "Vaelgor & Ezzorak", journalId = 2735, npcs = { 242056, 244552 } },
        { encounterId = 3179, name = "Fallen-King Salhadaar", journalId = 2736, npcs = { 240432 } },
        { encounterId = 3180, name = "Lightblinded Vanguard", journalId = 2737, npcs = { 240431, 240437, 240438 } },
        { encounterId = 3181, name = "Crown of the Cosmos", journalId = 2738, npcs = { 240430, 243805, 243810, 243811 } }
    } },
    { name = "The Dreamrift", instanceId = 2939, collapsed = true, bosses = {
        { encounterId = 3306, name = "Chimaerus the Undreamt God", journalId = 2795, npcs = { 245569 } }
    } },
    { name = "March on Quel'Danas", instanceId = 2913, collapsed = true, bosses = {
        { encounterId = 3182, name = "Belo'ren, Child of Al'ar", journalId = 2739, npcs = { 240387 } },
        { encounterId = 3183, name = "Midnight Falls", journalId = 2740, npcs = { 240391 } }
    } }
}

--Bosses by encounter id: { name, raid = the raid's name, order = its place in the raid list, journalId, npcs }
ns.bosses = {}
for _, raid in ipairs(ns.raids) do
    for order, boss in ipairs(raid.bosses) do
        ns.bosses[boss.encounterId] = { name = boss.name, raid = raid.name, order = order, journalId = boss.journalId, npcs = boss.npcs }
    end
end

ns.difficulties = {
    [15] = { slug = "hero", name = "Heroic" },
    [16] = { slug = "myth", name = "Mythic" }
}

--Other difficulty ids that use the plans of one of the above: 233 is Mythic - Flexible Raiding
ns.difficultyAliases = { [233] = 16 }
