local _, ns = ...

--Healer specs by specialization id (https://warcraft.wiki.gg/wiki/SpecializationID). The key is used in the saved settings
ns.specs = {
    [256] = { key = "Discipline", name = "Discipline Priest" },
    [257] = { key = "HolyPriest", name = "Holy Priest" },
    [65] = { key = "HolyPaladin", name = "Holy Paladin" },
    [105] = { key = "RestoDruid", name = "Restoration Druid" },
    [264] = { key = "RestoShaman", name = "Restoration Shaman" },
    [1468] = { key = "Preservation", name = "Preservation Evoker" }
}

--Spec key => display name
ns.specNames = {}
for _, spec in pairs(ns.specs) do
    ns.specNames[spec.key] = spec.name
end

--Ramps each spec starts with. They are copied into the saved settings and can be changed on the Ramps tab.
--spellId is the spell MRT notes use for the ramp. Steps are written in the ramp format, see Core/Ramps.lua.
--Sequences follow the Midnight 12.1 healing guides: the ramp lands when the damage does
ns.starterRamps = {
    Discipline = {
        --Evangelism casts a free Radiance and makes the next two instant, so it goes in the middle of the ramp
        ["Evangelism"] = {
            spellId = 472433,
            steps = "charges 194509 | Save Radiance charges | setup\n" ..
                "6gcd | Start ramp: Pain, Shield, Flash Heal | setup | icon 17 | say Start ramp\n" ..
                "3gcd | Evangelism\n" ..
                "2gcd | Radiance twice | icon 194509\n" ..
                "0 | Mind Blast, Penance | icon 47540 | say Penance"
        },
        ["Ultimate Penitence"] = {
            spellId = 421453,
            steps = "charges 194509 | Save Radiance charges | setup\n" ..
                "6gcd | Start ramp: Pain, Shield, Flash Heal | setup | icon 17 | say Start ramp\n" ..
                "3gcd | Radiance twice | icon 194509\n" ..
                "1gcd | Mind Blast | icon 8092\n" ..
                "0 | Ultimate Penitence"
        }
    },
    Preservation = {
        --Stores two Dream Breaths (two charges with Flameshaper) and Temporal Anomaly, released when the damage lands.
        --Stasis releases on its own 30 seconds after the third spell is stored
        ["Stasis"] = {
            spellId = 370537,
            steps = "charges 355936 | Save Dream Breath charges | setup | icon 355936\n" ..
                "20 | Fill Stasis: Dream Breath twice, Temporal Anomaly | setup | icon 370537 | say Fill Stasis\n" ..
                "3 | Release soon | countdown | icon 370564\n" ..
                "0 | Release Stasis | icon 370564"
        }
    },
    RestoDruid = {
        --Tranquility extends the Rejuvenations that are out when it is cast
        ["Tranquility"] = {
            spellId = 740,
            steps = "12 | Spread Rejuvenation | setup | icon 774 | say Rejuvenations\n" ..
                "3 | Tranquility soon | countdown\n" ..
                "0 | Tranquility"
        },
        --Tree of Life goes before the Rejuvenations to make them cheaper and stronger, Swiftmend and Wild Growth as the damage lands
        ["Tree of Life"] = {
            spellId = 33891,
            steps = "15 | Tree of Life, then Rejuvenations | setup | icon 33891 | say Tree of Life\n" ..
                "0 | Swiftmend, Wild Growth | icon 48438"
        }
    },
    RestoShaman = {
        --Spirit Link only reaches allies within 13 yards, so the group stacks first
        ["Spirit Link Totem"] = {
            spellId = 98008,
            steps = "6 | Stack for Spirit Link | setup | icon 98008 | say Stack up\n" ..
                "0 | Spirit Link Totem"
        }
    },
    HolyPriest = {},
    HolyPaladin = {}
}

--Starter ramps of version 2.0.0, before they were checked against Midnight. Ones still unchanged in the saved settings are
--replaced by the current starter ramps
ns.outdatedStarterRamps = {
    Discipline = {
        ["Evangelism"] = "charges 194509 | Save Radiance charges | setup\n12gcd | Start atonement ramp | setup | icon 17 | say Start ramp\n3gcd | Double Radiance | icon 194509\n0 | Evangelism",
        ["Ultimate Penitence"] = "8gcd | Start atonement ramp | setup | icon 17 | say Start ramp\n3gcd | Radiance | icon 194509\n3 | Penitence soon | countdown\n0 | Ultimate Penitence"
    },
    Preservation = {
        ["Stasis"] = "charges 443328 | Save Engulf charges | setup\n30 | Hold Dream Breath | setup | icon 355936\n20 | Cast Stasis and fill it | setup\n3 | Release soon | countdown | icon 370564\n0 | Release Stasis | icon 370564",
        ["Emerald Communion"] = "20 | Spread Reversion | setup | icon 366155\n3 | Communion soon | countdown\n0 | Emerald Communion"
    },
    RestoDruid = {
        ["Flourish"] = "15 | Spread Rejuvenation | setup | icon 774\n3 | Flourish soon | countdown\n0 | Flourish"
    },
    RestoShaman = {
        ["Cloudburst Totem"] = "18 | Drop Cloudburst | setup\n3 | Cloudburst pops soon | countdown"
    }
}
