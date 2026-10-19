local _, ns = ...

--Abilities of each boss, by encounter id, in the order and groups BigWigs uses, with the stages they happen in
--(BigWigs' stage numbers, an intermission is the stage before it plus 0.5) and mythic = true for abilities only on
--Mythic. Generated from BigWigs' boss modules. Abilities a boss mod shows bars for that aren't listed here are added
--in the planner after a pull
ns.bossAbilities = {
    [3420] = { -- Sszorak
        { spellId = 1285732, name = "Howling Maelstrom" },
        { spellId = 1277025, name = "Apex Predator" },
        { spellId = 1305959, name = "Venomous Surge" },
        { spellId = 1285425, name = "Raging Crosswinds" },
        { spellId = 1296898, name = "Unbound Ferocity", group = "Mythic", mythic = true }
    },
    [3445] = { -- Entombed Sentinels
        { spellId = 1284588, name = "Vitriolic Stasis" },
        { spellId = 1296878, name = "Shifting Protovenom", group = "Vashnik the Malignant (Mythic)", mythic = true },
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
    [3429] = { -- The Coiled Altar
        { spellId = 1282487, name = "Fangs of the Coiled Altar", group = "Stage One: Serpent's Bargain", phases = { 1 } },
        { spellId = 1299960, name = "Toxic Deluge", group = "Stage One: Serpent's Bargain", phases = { 1, 3 } },
        { spellId = 1283489, name = "Guillotine", group = "Stage One: Serpent's Bargain", phases = { 1 } },
        { spellId = 1299680, name = "Sever", group = "Stage One: Serpent's Bargain", phases = { 1 } },
        { spellId = 1282281, name = "Venomfang", group = "Stage One: Serpent's Bargain", phases = { 1 } },
        { spellId = 1283832, name = "Axegrinder", group = "Stage One: Serpent's Bargain", phases = { 1 } },
        { spellId = 1289900, name = "Dreadmarch", group = "Stage Two: Usurper's Reprisal", phases = { 2, 3 } },
        { spellId = 1285911, name = "Unnerving Fixation", group = "Stage Two: Usurper's Reprisal", phases = { 2, 3 } },
        { spellId = 1286573, name = "Soul Sever", group = "Stage Two: Usurper's Reprisal", phases = { 2 } },
        { spellId = 1286918, name = "Eternal Nightfall", group = "Stage Two: Usurper's Reprisal", phases = { 2, 3 } },
        { spellId = 1286441, name = "Spiritcackle", group = "Stage Two: Usurper's Reprisal", phases = { 2, 3 } },
        { spellId = 1286895, name = "Gloombomb", group = "Stage Two: Usurper's Reprisal", phases = { 2, 3 } },
        { spellId = 1298381, name = "Defilement of the Coiled Altar", group = "Zul'jan", phases = { 3 } },
        { spellId = 1299266, name = "Grim Guillotine", group = "Zul'jan", phases = { 3 } },
        { spellId = 1307279, name = "Blighted Sever", group = "Zul'jan", phases = { 3 } }
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
    [3470] = { -- Nek'zali the Soulcoiler
        { spellId = 1293212, name = "Grasping Depths", group = "Mythic", mythic = true },
        { spellId = 1285681, name = "Soulcoil Ignition", group = "Stage One: Soulcoiler Initiation", phases = { 1 } },
        { spellId = 1287426, name = "Essence Rend", group = "Stage One: Soulcoiler Initiation", phases = { 1 } },
        { spellId = 1295397, name = "Restless Amani", group = "Stage One: Soulcoiler Initiation", phases = { 1 } },
        { spellId = 1287533, name = "Gravebound Advance", group = "Stage One: Soulcoiler Initiation", phases = { 1 } },
        { spellId = 1292036, name = "Possession Barrage", group = "Stage One: Soulcoiler Initiation", phases = { 1 } },
        { spellId = 1305421, name = "Hungering Pyre", group = "Intermission: Ritual of Awakening", phases = { 1.5 } },
        { spellId = 1299673, name = "Invoke", group = "Stage Two: Uncoiling", phases = { 2 } }
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
    },
    [3492] = { -- Ula'tek
        { spellId = 1292188, name = "Caustic Waves", group = "Stage One: Fury of the Serpent Mother", phases = { 1, 3 } },
        { spellId = 1300751, name = "Call of the Serpent", group = "Stage One: Fury of the Serpent Mother", phases = { 1, 3 } },
        { spellId = 1298367, name = "Mother's Wrath", group = "Stage One: Fury of the Serpent Mother", phases = { 1, 3 } },
        { spellId = 1298559, name = "Gore Rattle", group = "Stage One: Fury of the Serpent Mother", phases = { 1 } },
        { spellId = 1296301, name = "Mephitic Thrash", group = "Stage One: Fury of the Serpent Mother", phases = { 1 } },
        { spellId = 1300530, name = "Spectral Coils", group = "Stage One: Fury of the Serpent Mother", phases = { 1, 2.5 } },
        { spellId = 1292999, name = "Submerge", group = "Stage One: Fury of the Serpent Mother", phases = { 1 } },
        { spellId = 1286860, name = "Rage of the Shackled", group = "Stage One: Fury of the Serpent Mother", phases = { 1, 2, 3 } },
        { spellId = 1310738, name = "Toxic Womb", group = "Stage One: Fury of the Serpent Mother", phases = { 1 } },
        { spellId = 1310763, name = "Fester Burst", group = "Stage One: Fury of the Serpent Mother", phases = { 1 } },
        { spellId = 1299757, name = "Toxic Incubation", group = "Stage One: Fury of the Serpent Mother", phases = { 1 } },
        { spellId = 1302982, name = "Virulent Spit", group = "Stage Two: Children of the Doomscale", phases = { 2 } },
        { spellId = 1301117, name = "Grasping Fangs", group = "Doomscale Warden", phases = { 2 } },
        { spellId = 1290779, name = "Malice", group = "Doomscale Warden", phases = { 2 } },
        { spellId = 1301213, name = "Shadow Molt", group = "Doomscale Warden", phases = { 2 } },
        { spellId = 1301510, name = "Circling Prey", group = "Stage Three: Ula'tek's Ascension", phases = { 3 } },
        { spellId = 1300635, name = "Submerge", group = "Stage Three: Ula'tek's Ascension", phases = { 3 } },
        { spellId = 1295905, name = "Serpent's Bite", group = "Stage Three: Ula'tek's Ascension", phases = { 3 } },
        { spellId = 1286905, name = "Fury Unleashed", group = "Stage Three: Ula'tek's Ascension", phases = { 3 } }
    },
    [3513] = { -- Kith'ix
        { spellId = 1301511, name = "Voidswarm", group = "Stage One: Darkness' Domain", phases = { 1 } },
        { spellId = 1304424, name = "Extinguish", group = "Stage One: Darkness' Domain", phases = { 1 } },
        { spellId = 1304508, name = "Light's Embrace", group = "Stage One: Darkness' Domain", phases = { 1 } },
        { spellId = 1304045, name = "Unspeakable Horrors", group = "Stage One: Darkness' Domain", phases = { 1 } },
        { spellId = 1303681, name = "Twisted Appendage", group = "Stage One: Darkness' Domain", phases = { 1 } },
        { spellId = 1304930, name = "Dark Devastation", group = "Stage One: Darkness' Domain", phases = { 1 } },
        { spellId = 1302951, name = "Suffocating Darkness", group = "Intermission: Suffocating Darkness", phases = { 1.5 } },
        { spellId = 1303406, name = "Abyssal Grasp", group = "Intermission: Suffocating Darkness", phases = { 1.5 } },
        { spellId = 1303169, name = "Divine Radiance", group = "Intermission: Suffocating Darkness", phases = { 1.5 } },
        { spellId = 1308873, name = "Null Gate", group = "Stage Two: Last Light", phases = { 2 } },
        { spellId = 1318467, name = "Negation", group = "Stage Two: Last Light", phases = { 2 } },
        { spellId = 1301479, name = "Eightfold Eclipse", group = "Stage Two: Last Light", phases = { 2 } }
    },
    [3379] = { -- Nymrissa Wavecaller
        { spellId = 1276710, name = "Alluring Bubble" },
        { spellId = 1257717, name = "Alluring Bubble" },
        { spellId = 1258668, name = "Swirling Whirlpools" },
        { spellId = 1260837, name = "Abyssal Rain" },
        { spellId = 1282937, name = "Iceblade Flurry" },
        { spellId = 1313393, name = "Chilling Frost" },
        { spellId = 1268562, name = "Water Jet", group = "Mythic", mythic = true }
    },
    [3176] = { -- Imperator Averzian
        { spellId = 1251361, name = "Shadow's Advance" },
        { spellId = 1262036, name = "Void Rupture" },
        { spellId = 1249262, name = "Umbral Collapse" },
        { spellId = 1280015, name = "Void Marked" },
        { spellId = 1260712, name = "Oblivion's Wrath" },
        { spellId = 1258883, name = "Void Fall" },
        { spellId = 1249251, name = "Dark Upheaval" }
    },
    [3177] = { -- Vorasius
        { spellId = 1256855, name = "Void Breath" },
        { spellId = 1254199, name = "Parasite Expulsion" },
        { spellId = 1241692, name = "Shadowclaw Slam" },
        { spellId = 1260052, name = "Primordial Roar" }
    },
    [3178] = { -- Vaelgor & Ezzorak
        { spellId = 1249748, name = "Midnight Flames" },
        { spellId = 1280458, name = "Grappling Maw" },
        { spellId = 1262623, name = "Nullbeam", group = "Vaelgor" },
        { spellId = 1244672, name = "Nullzone", group = "Vaelgor" },
        { spellId = 1244221, name = "Dread Breath", group = "Vaelgor" },
        { spellId = 1265131, name = "Vaelwing", group = "Vaelgor" },
        { spellId = 1245391, name = "Gloom", group = "Ezzorak" },
        { spellId = 1244917, name = "Void Howl", group = "Ezzorak" },
        { spellId = 1245645, name = "Rakfang", group = "Ezzorak" }
    },
    [3179] = { -- Fallen-King Salhadaar
        { spellId = 1247738, name = "Void Convergence" },
        { spellId = 1246175, name = "Entropic Unraveling" },
        { spellId = 1250803, name = "Shattering Twilight" },
        { spellId = 1254081, name = "Fractured Projection" },
        { spellId = 1248697, name = "Despotic Command" },
        { spellId = 1250686, name = "Twisting Obscurity" }
    },
    [3180] = { -- Lightblinded Vanguard
        { spellId = 1248449, name = "Aura of Wrath", group = "Commander Venel Lightblood" },
        { spellId = 1248983, name = "Execution Sentence", group = "Commander Venel Lightblood" },
        { spellId = 1246765, name = "Divine Storm", group = "Commander Venel Lightblood" },
        { spellId = 1246749, name = "Sacred Toll", group = "Commander Venel Lightblood" },
        { spellId = 1246736, name = "Judgement", group = "Commander Venel Lightblood" },
        { spellId = 1246162, name = "Aura of Devotion", group = "General Amias Bellamy" },
        { spellId = 1248644, name = "Divine Toll", group = "General Amias Bellamy" },
        { spellId = 1246485, name = "Avenger's Shield", group = "General Amias Bellamy" },
        { spellId = 1251857, name = "Judgement", group = "General Amias Bellamy" },
        { spellId = 1248451, name = "Aura of Peace", group = "War Chaplain Senn" },
        { spellId = 1248710, name = "Tyr's Wrath", group = "War Chaplain Senn" },
        { spellId = 1255738, name = "Searing Radiance", group = "War Chaplain Senn" },
        { spellId = 1248674, name = "Sacred Shield", group = "War Chaplain Senn" },
        { spellId = 1276243, name = "Zealous Spirit", group = "Mythic", mythic = true }
    },
    [3181] = { -- Crown of the Cosmos
        { spellId = 1233602, name = "Silverstrike Arrow", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1232467, name = "Grasp of Emptiness", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1255368, name = "Void Expulsion", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1233865, name = "Null Corona", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1233787, name = "Dark Hand [Morium]", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1243743, name = "Interrupting Tremor [Demiar]", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1243753, name = "Ravenous Abyss [Vorelus]", group = "Stage One: The Void's Spire", phases = { 1 } },
        { spellId = 1243982, name = "Silverstrike Barrage", group = "Intermission: Crushing Singularity", phases = { 1.5 } },
        { spellId = 1237614, name = "Ranger Captain's Mark", group = "Stage Two: The Severed Rift", phases = { 2 } },
        { spellId = 1237038, name = "Voidstalker's Sting", group = "Stage Two: The Severed Rift", phases = { 2 } },
        { spellId = 1237837, name = "Call of the Void", group = "Stage Two: The Severed Rift", phases = { 2 } },
        { spellId = 1246918, name = "Cosmic Barrier", group = "Stage Two: The Severed Rift", phases = { 2 } },
        { spellId = 1246461, name = "Rift Slash", group = "Stage Two: The Severed Rift", phases = { 2 } },
        { spellId = 1261016, name = "Rift Simulacrum", group = "Stage Two: The Severed Rift", phases = { 2 } },
        { spellId = 1238843, name = "Devouring Cosmos", group = "Stage Three: The End of the End", phases = { 3 } },
        { spellId = 1239080, name = "Aspect of the End", group = "Stage Three: The End of the End", phases = { 3 } },
        { spellId = 1261339, name = "Cosmic Portal", group = "Stage Three: The End of the End", phases = { 3 } }
    },
    [3306] = { -- Chimaerus the Undreamt God
        { spellId = 1262289, name = "Alndust Upheaval", group = "Stage One: Insatiable Hunger", phases = { 1 } },
        { spellId = 1258610, name = "Rift Emergence", group = "Stage One: Insatiable Hunger", phases = { 1 } },
        { spellId = 1257087, name = "Consuming Miasma", group = "Stage One: Insatiable Hunger", phases = { 1 } },
        { spellId = 1246653, name = "Caustic Phlegm", group = "Stage One: Insatiable Hunger", phases = { 1 } },
        { spellId = 1272726, name = "Rending Tear", group = "Stage One: Insatiable Hunger", phases = { 1 } },
        { spellId = 1245396, name = "Consume", group = "Stage One: Insatiable Hunger", phases = { 1 } },
        { spellId = 1245486, name = "Corrupted Devastation", group = "Stage Two: To The Skies", phases = { 2 } },
        { spellId = 1245406, name = "Ravenous Dive", group = "Stage Two: To The Skies", phases = { 2 } },
        { spellId = 1246621, name = "Caustic Phlegm", group = "Stage Two: To The Skies", phases = { 2 } },
        { spellId = 1257085, name = "Consuming Miasma", group = "Stage Two: To The Skies", phases = { 2 } },
        { spellId = 1264756, name = "Rift Madness", group = "Mythic", phases = { 2 }, mythic = true }
    },
    [3182] = { -- Belo'ren, Child of Al'ar
        { spellId = 1242515, name = "Voidlight Convergence", group = "Stage 1", phases = { 1 } },
        { spellId = 1241282, name = "Embers of Belo'ren", group = "Stage 1", phases = { 1 } },
        { spellId = 1241292, name = "Light/Void Dive", group = "Stage 1", phases = { 1 } },
        { spellId = 1242981, name = "Radiant Echoes", group = "Stage 1", phases = { 1 } },
        { spellId = 1260763, name = "Guardian's Edict", group = "Stage 1", phases = { 1 } },
        { spellId = 1244344, name = "Eternal Burns", group = "Stage 1", phases = { 1 } },
        { spellId = 1242260, name = "Infused Quills", group = "Stage 1", phases = { 1 } },
        { spellId = 1246709, name = "Death Drop", group = "Stage 1", phases = { 1 } },
        { spellId = 1241313, name = "Rebirth", group = "Stage 2", phases = { 2 } }
    },
    [3183] = { -- Midnight Falls
        { spellId = 1253915, name = "Heaven's Glaives", group = "Stage 1", phases = { 1 } },
        { spellId = 1279420, name = "Dark Quasar [Stage 1 Only]", group = "Stage 1", phases = { 1 } },
        { spellId = 1249620, name = "Death's Dirge", group = "Stage 1", phases = { 1 } },
        { spellId = 1249609, name = "Dark Rune", group = "Stage 1", phases = { 1 } },
        { spellId = 1251386, name = "Safeguard Prism", group = "Stage 1", phases = { 1 } },
        { spellId = 1267049, name = "Heaven's Lance", group = "Stage 1", phases = { 1 } },
        { spellId = 1284980, name = "Grim Symphony", group = "Mythic", phases = { 1 }, mythic = true },
        { spellId = 1284931, name = "Termination Prism", group = "Mythic", phases = { 1 }, mythic = true },
        { spellId = 1282441, name = "Starsplinter", group = "Intermission", phases = { 1.5 } },
        { spellId = 1282469, name = "Dark Quasar [Intermission Only]", group = "Intermission", phases = { 1.5 } },
        { spellId = 1284525, name = "Galvanize", group = "Stage 2", phases = { 2 } },
        { spellId = 1282412, name = "Core Harvest", group = "Stage 2", phases = { 2 } },
        { spellId = 1281194, name = "Dark Meltdown", group = "Stage 2", phases = { 2 } },
        { spellId = 1250898, name = "The Dark Archangel", group = "Stage 3", phases = { 3 } },
        { spellId = 1266388, name = "Dark Constellation", group = "Stage 3", phases = { 3 } },
        { spellId = 1266897, name = "Light Siphon", group = "Stage 3", phases = { 3 } },
        { spellId = 1273158, name = "Death's Requiem", group = "Mythic", phases = { 3 }, mythic = true },
        { spellId = 1276525, name = "Heaven & Hell", group = "Mythic", phases = { 3 }, mythic = true }
    }
}

--The stages of each boss, with their names, for bosses BigWigs splits into stages
ns.bossStages = {
    [3429] = { -- The Coiled Altar
        { stage = 1, name = "Stage One: Serpent's Bargain" },
        { stage = 2, name = "Stage Two: Usurper's Reprisal" },
        { stage = 2.5, name = "Intermission: The Claimed Vessel" },
        { stage = 3, name = "Stage Three: Coiled Union" }
    },
    [3470] = { -- Nek'zali the Soulcoiler
        { stage = 1, name = "Stage One: Soulcoiler Initiation" },
        { stage = 1.5, name = "Intermission: Ritual of Awakening" },
        { stage = 2, name = "Stage Two: Uncoiling" }
    },
    [3492] = { -- Ula'tek
        { stage = 1, name = "Stage One: Fury of the Serpent Mother" },
        { stage = 2, name = "Stage Two: Children of the Doomscale" },
        { stage = 2.5, name = "Intermission: The Shattering" },
        { stage = 3, name = "Stage Three: Ula'tek's Ascension" }
    },
    [3513] = { -- Kith'ix
        { stage = 1, name = "Stage One: Darkness' Domain" },
        { stage = 1.5, name = "Intermission: Suffocating Darkness" },
        { stage = 2, name = "Stage Two: Last Light" }
    },
    [3181] = { -- Crown of the Cosmos
        { stage = 1, name = "Stage One: The Void's Spire" },
        { stage = 1.5, name = "Intermission: Crushing Singularity" },
        { stage = 2, name = "Stage Two: The Severed Rift" },
        { stage = 3, name = "Stage Three: The End of the End" }
    },
    [3306] = { -- Chimaerus the Undreamt God
        { stage = 1, name = "Stage One: Insatiable Hunger" },
        { stage = 2, name = "Stage Two: To The Skies" }
    },
    [3182] = { -- Belo'ren, Child of Al'ar
        { stage = 1, name = "Stage 1" },
        { stage = 2, name = "Stage 2" }
    },
    [3183] = { -- Midnight Falls
        { stage = 1, name = "Stage 1" },
        { stage = 1.5, name = "Intermission" },
        { stage = 2, name = "Stage 2" },
        { stage = 3, name = "Stage 3" }
    }
}
