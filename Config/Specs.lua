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
--spellId is the spell MRT notes use for the ramp. Steps are written in the ramp format, see Core/Ramps.lua
ns.starterRamps = {
    Discipline = {
        ["Evangelism"] = {
            spellId = 472433,
            steps = "charges 194509 | Save Radiance charges | setup\n" ..
                "12gcd | Start atonement ramp | setup | icon 17 | say Start ramp\n" ..
                "3gcd | Double Radiance | icon 194509\n" ..
                "0 | Evangelism"
        },
        ["Ultimate Penitence"] = {
            spellId = 421453,
            steps = "8gcd | Start atonement ramp | setup | icon 17 | say Start ramp\n" ..
                "3gcd | Radiance | icon 194509\n" ..
                "3 | Penitence soon | countdown\n" ..
                "0 | Ultimate Penitence"
        }
    },
    Preservation = {
        ["Stasis"] = {
            spellId = 370537,
            steps = "charges 443328 | Save Engulf charges | setup\n" ..
                "30 | Hold Dream Breath | setup | icon 355936\n" ..
                "20 | Cast Stasis and fill it | setup\n" ..
                "3 | Release soon | countdown | icon 370564\n" ..
                "0 | Release Stasis | icon 370564"
        },
        ["Emerald Communion"] = {
            spellId = 370960,
            steps = "20 | Spread Reversion | setup | icon 366155\n" ..
                "3 | Communion soon | countdown\n" ..
                "0 | Emerald Communion"
        }
    },
    RestoDruid = {
        ["Flourish"] = {
            spellId = 197721,
            steps = "15 | Spread Rejuvenation | setup | icon 774\n" ..
                "3 | Flourish soon | countdown\n" ..
                "0 | Flourish"
        }
    },
    RestoShaman = {
        ["Cloudburst Totem"] = {
            spellId = 157153,
            steps = "18 | Drop Cloudburst | setup\n" ..
                "3 | Cloudburst pops soon | countdown"
        }
    },
    HolyPriest = {},
    HolyPaladin = {}
}
