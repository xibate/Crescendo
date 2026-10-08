local _, ns = ...

--Abilities of the current raid's bosses, by encounter id, in the order and groups the boss mods use.
--The planner lists them to assign ramps and spells to. Abilities a boss mod shows bars for that aren't listed
--here are added in the planner after a pull
ns.bossAbilities = {
    [3420] = { -- Sszorak
        { spellId = 1285732, name = "Howling Maelstrom" },
        { spellId = 1277025, name = "Apex Predator" },
        { spellId = 1305959, name = "Venomous Surge" },
        { spellId = 1285425, name = "Raging Crosswinds" },
        { spellId = 1296898, name = "Unbound Ferocity", group = "Mythic" }
    },
    [3421] = { -- The Twin Fangs
        { spellId = 1308556, name = "Submerge" },
        { spellId = 1289192, name = "Caustic Deluge", group = "Vexhul" },
        { spellId = 1291404, name = "Venomous Emergence", group = "Vexhul" },
        { spellId = 1291478, name = "Corrosive Spit", group = "Vexhul" },
        { spellId = 1290956, name = "Stir the Depths", group = "Vexhul" },
        { spellId = 1294293, name = "Vile Flood", group = "Vexhul" },
        { spellId = 1303230, name = "Blood Torrent", group = "Ithraz" },
        { spellId = 1308356, name = "Rouse the Brood", group = "Ithraz" },
        { spellId = 1290516, name = "Ravenous Feast", group = "Ithraz" },
        { spellId = 1290809, name = "Coiling Ichor", group = "Ithraz" },
        { spellId = 1288538, name = "Stone Breaker", group = "Ithraz" },
        { spellId = 1306872, name = "Sanguine Storm", group = "Ithraz" }
    },
    [3429] = { -- The Coiled Altar
        { spellId = 1282487, name = "Fangs of the Coiled Altar", group = "Stage One: Serpent's Bargain" },
        { spellId = 1299960, name = "Toxic Deluge", group = "Stage One: Serpent's Bargain" },
        { spellId = 1283489, name = "Guillotine", group = "Stage One: Serpent's Bargain" },
        { spellId = 1299680, name = "Sever", group = "Stage One: Serpent's Bargain" },
        { spellId = 1282281, name = "Venomfang", group = "Stage One: Serpent's Bargain" },
        { spellId = 1283832, name = "Axegrinder", group = "Stage One: Serpent's Bargain" },
        { spellId = 1289900, name = "Dreadmarch", group = "Stage Two: Usurper's Reprisal" },
        { spellId = 1285911, name = "Unnerving Fixation", group = "Stage Two: Usurper's Reprisal" },
        { spellId = 1286573, name = "Soul Sever", group = "Stage Two: Usurper's Reprisal" },
        { spellId = 1286918, name = "Eternal Nightfall", group = "Stage Two: Usurper's Reprisal" },
        { spellId = 1286441, name = "Spiritcackle", group = "Stage Two: Usurper's Reprisal" },
        { spellId = 1286895, name = "Gloombomb", group = "Stage Two: Usurper's Reprisal" },
        { spellId = 1298381, name = "Defilement of the Coiled Altar", group = "Zul'jan" },
        { spellId = 1299266, name = "Grim Guillotine", group = "Zul'jan" },
        { spellId = 1307279, name = "Blighted Sever", group = "Zul'jan" }
    },
    [3445] = { -- Entombed Sentinels
        { spellId = 1284588, name = "Vitriolic Stasis" },
        { spellId = 1296878, name = "Shifting Protovenom", group = "Vashnik the Malignant (Mythic)" },
        { spellId = 1284251, name = "Venom Coagulation", group = "Breath of Ula'tek" },
        { spellId = 1284434, name = "Toxic Droplets", group = "Breath of Ula'tek" },
        { spellId = 1284458, name = "Empowering Slam", group = "Breath of Ula'tek" },
        { spellId = 1284483, name = "Blighted Blood", group = "Blood of Ula'tek" },
        { spellId = 1288232, name = "Unstable Miasma", group = "Blood of Ula'tek" },
        { spellId = 1284487, name = "Bloodvenom Injection", group = "Blood of Ula'tek" }
    },
    [3455] = { -- Vashnik the Malignant
        { spellId = 1283164, name = "Imbibe" },
        { spellId = 1282525, name = "Malignant Catalyst" },
        { spellId = 1281907, name = "Plague Froth" },
        { spellId = 1280935, name = "Dripping Fangs" },
        { spellId = 1282117, name = "Adaptive Infection" }
    },
    [3470] = { -- Nek'zali the Soulcoiler
        { spellId = 1293212, name = "Grasping Depths", group = "Mythic" },
        { spellId = 1285681, name = "Soulcoil Ignition", group = "Stage One: Soulcoiler Initiation" },
        { spellId = 1287426, name = "Essence Rend", group = "Stage One: Soulcoiler Initiation" },
        { spellId = 1295397, name = "Restless Amani", group = "Stage One: Soulcoiler Initiation" },
        { spellId = 1287533, name = "Gravebound Advance", group = "Stage One: Soulcoiler Initiation" },
        { spellId = 1292036, name = "Possession Barrage", group = "Stage One: Soulcoiler Initiation" },
        { spellId = 1305421, name = "Hungering Pyre", group = "Intermission: Ritual of Awakening" },
        { spellId = 1299673, name = "Invoke", group = "Stage Two: Uncoiling" }
    },
    [3492] = { -- Ula'tek
        { spellId = 1292188, name = "Caustic Waves", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1300751, name = "Call of the Serpent", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1298367, name = "Mother's Wrath", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1298559, name = "Gore Rattle", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1296301, name = "Mephitic Thrash", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1300530, name = "Spectral Coils", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1292999, name = "Submerge", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1286860, name = "Rage of the Shackled", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1310738, name = "Toxic Womb", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1310763, name = "Fester Burst", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1299757, name = "Toxic Incubation", group = "Stage One: Fury of the Serpent Mother" },
        { spellId = 1302982, name = "Virulent Spit", group = "Stage Two: Children of the Doomscale" },
        { spellId = 1301117, name = "Grasping Fangs", group = "Doomscale Warden" },
        { spellId = 1290779, name = "Malice", group = "Doomscale Warden" },
        { spellId = 1301213, name = "Shadow Molt", group = "Doomscale Warden" },
        { spellId = 1301510, name = "Circling Prey", group = "Stage Three: Ula'tek's Ascension" },
        { spellId = 1300635, name = "Submerge", group = "Stage Three: Ula'tek's Ascension" },
        { spellId = 1295905, name = "Serpent's Bite", group = "Stage Three: Ula'tek's Ascension" },
        { spellId = 1286905, name = "Fury Unleashed", group = "Stage Three: Ula'tek's Ascension" }
    },
    [3497] = { -- The Lost Explorers
        { spellId = 1296535, name = "Disgusting Fish", group = "Mor'zahi" },
        { spellId = 1297022, name = "Mor'zahi's Command", group = "Mor'zahi" },
        { spellId = 1292779, name = "Final Ascension", group = "Mor'zahi" },
        { spellId = 1290711, name = "Blink Nova", group = "Scrollsage Iku" },
        { spellId = 1286921, name = "Icebound Flames", group = "Scrollsage Iku" },
        { spellId = 1295854, name = "Shredding Shards", group = "Scrollsage Iku" },
        { spellId = 1295886, name = "Frostfire Volley", group = "Scrollsage Iku" },
        { spellId = 1291390, name = "Cataclysmic Invocation", group = "Scrollsage Iku" },
        { spellId = 1291759, name = "Shell Spin", group = "First Mate Nama" },
        { spellId = 1296092, name = "Mighty Thud", group = "First Mate Nama" },
        { spellId = 1291933, name = "Throw Junk", group = "Trader Gebbo" },
        { spellId = 1295817, name = "Fling Fish", group = "Trader Gebbo" },
        { spellId = 1292104, name = "Mushroom Toss", group = "Trader Gebbo" },
        { spellId = 1296249, name = "Explosive Surprise", group = "Trader Gebbo" }
    }
}
