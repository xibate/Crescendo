local _, ns = ...

local DATABASE_VERSION = 2

--Saved settings:
-- options        display, text to speech and MRT note settings
-- testing        testMode
-- plans          plans[spec][difficulty slug][encounter id] = plan text, see Core/PlanText.lua
-- testPlans      testPlans[spec] = plan text used in testing mode
-- ramps          ramps[spec][ramp name] = { spellId = spell MRT notes use, steps = steps text, see Core/Ramps.lua }
-- seenAbilities  seenAbilities[encounter id][ability name] = spell id, the abilities boss mods showed bars for
-- ui             what is selected in the options window
local defaults = {
    options = {
        toggleDisplay = false,
        framePositionX = 0,
        framePositionY = 200,
        growDirection = 'top',
        textSize = 2,
        timerSize = 2.5,
        iconSizeW = 48,
        iconSizeH = 48,
        displaySpacing = 70,
        ttsEnabled = true,
        ttsVoice = 1,
        ttsRate = -1,
        ttsVolume = 100,
        preReqsOnly = false,
        readFromNote = false,
        mrtPersonalNote = false,
        timerDuration = 3
    },
    testing = { testMode = false },
    plans = {},
    testPlans = {},
    ramps = {},
    seenAbilities = {},
    ui = {}
}

local function Copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = Copy(inner)
    end
    return copy
end

local function Child(parent, key)
    if type(parent[key]) ~= 'table' then
        parent[key] = {}
    end
    return parent[key]
end

--Settings from before version 2 kept a timings box per ramp or spell, db[spec][difficulty][encounter id][name] = lines
--like '01:25', '00:50, p2' or '@Ability #2'. Those become plan lines like '01:25 - Name'. Spells had short names then,
--so they are written with the game's name of their spell
local RENAMED_RAMPS = { ['EC'] = 'Emerald Communion' }
local OLD_SPELL_NAMES = {
    ['Barrier'] = 62618, ['Pain Suppression'] = 33206, ['Leap of Faith'] = 73325, ['Mass Dispel'] = 32375, ['Mass Dispell'] = 32375,
    ['Divine Hymn'] = 64843, ['Apotheosis'] = 200183, ['Halo'] = 120517, ['Lightwell'] = 372835, ['Symbol of Hope'] = 64901,
    ['Guardian Spirit'] = 47788, ['Stasis Release'] = 370564, ['Dreamflight'] = 359816, ['Rewind'] = 363534, ['Engulf'] = 443328,
    ['Time Dilation'] = 357170, ['Time Spiral'] = 374968, ['Zephyr'] = 374227, ['Rescue'] = 370665, ['Spatial Paradox'] = 406735,
    ['Obsidian Scales'] = 363916, ['Renewing Blaze'] = 374348, ['Tranquility'] = 740, ['Stampeding Roar'] = 77761,
    ["Ursol's Vortex"] = 102793, ['Ironbark'] = 102342, ['Ascendance'] = 114052, ['Healing Tide Totem'] = 108280,
    ['Spirit Link Totem'] = 98008, ['Ancestral Protection Totem'] = 207399, ['Earthen Wall Totem'] = 198838,
    ['Wind Rush Totem'] = 192077, ['Totemic Recall'] = 108285, ['Avenging Wrath'] = 31884, ['Aura Mastery'] = 31821,
    ['Blessing of the Seasons'] = 395355, ['Blessing of Sacrifice'] = 6940, ['Blessing of Freedom'] = 1044,
    ['Blessing of Protection'] = 1022
}

local function EntryName(oldName)
    if RENAMED_RAMPS[oldName] then
        return RENAMED_RAMPS[oldName]
    end
    local spellId = OLD_SPELL_NAMES[oldName]
    if spellId then
        local info = C_Spell.GetSpellInfo(spellId)
        return info and info.name or tostring(spellId)
    end
    return oldName
end

local function ConvertTimings(timings, enabled)
    local lines = {}
    local names = {}
    for name in pairs(timings) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        if type(timings[name]) == 'string' and enabled[name] ~= false then
            local entry = EntryName(name)
            for line in ns:Lines(timings[name]) do
                line = line:match('^%s*(.-)%s*$')
                if line:find('^@') then
                    table.insert(lines, line .. ' - ' .. entry)
                elseif line ~= '' then
                    local time, phase = nil, nil
                    for part in line:gmatch('[^,]+') do
                        local phaseNumber = part:match('^%s*p%s*(%d+%.?%d*)%s*$')
                        if phaseNumber then
                            phase = phaseNumber
                        else
                            time = part:match('^%s*(.-)%s*$')
                        end
                    end
                    if time then
                        table.insert(lines, time .. (phase and (' p' .. phase) or '') .. ' - ' .. entry)
                    end
                end
            end
        end
    end
    return table.concat(lines, '\n')
end

local function MigrateTimingBoxes(db)
    local toggles = type(db.options.specs) == 'table' and db.options.specs or {}
    for _, spec in pairs(ns.specs) do
        local old = db[spec.key]
        if type(old) == 'table' then
            local enabled = type(toggles[spec.key]) == 'table' and toggles[spec.key] or {}
            for diffSlug, bosses in pairs(old) do
                if diffSlug == 'testTimers' then
                    if not db.testPlans[spec.key] then
                        db.testPlans[spec.key] = ConvertTimings(bosses, enabled)
                    end
                elseif type(bosses) == 'table' then
                    for encounterId, timings in pairs(bosses) do
                        local plans = Child(Child(db.plans, spec.key), diffSlug)
                        if type(timings) == 'table' and not plans[encounterId] then
                            local text = ConvertTimings(timings, enabled)
                            if text ~= '' then
                                plans[encounterId] = text
                            end
                        end
                    end
                end
            end
        end
    end
end

--Creates the saved settings or fills in what is missing. Only nil is replaced, so options turned off stay off
function ns:InitDatabase()
    if type(ZynxRampHelperDB) ~= 'table' then
        ZynxRampHelperDB = {}
    end
    local db = ZynxRampHelperDB
    for group, values in pairs(defaults) do
        if type(db[group]) ~= 'table' then
            db[group] = {}
        end
        for key, value in pairs(values) do
            if db[group][key] == nil then
                db[group][key] = Copy(value)
            end
        end
    end
    db.options.toggleDisplay = false
    for _, spec in pairs(ns.specs) do
        if db.ramps[spec.key] == nil then
            db.ramps[spec.key] = Copy(ns.starterRamps[spec.key] or {})
        end
    end
    if (db.version or 1) < 2 then
        MigrateTimingBoxes(db)
    end
    db.version = DATABASE_VERSION
    ns.db = db
end

--Puts the display, text to speech and MRT note options back to their defaults
function ns:ResetOptions()
    for key, value in pairs(defaults.options) do
        ns.db.options[key] = Copy(value)
    end
end

function ns:GetPlan(specKey, diffSlug, encounterId)
    return Child(Child(ns.db.plans, specKey), diffSlug)[tostring(encounterId)] or ''
end

function ns:SetPlan(specKey, diffSlug, encounterId, text)
    Child(Child(ns.db.plans, specKey), diffSlug)[tostring(encounterId)] = text
end

function ns:GetTestPlan(specKey)
    return ns.db.testPlans[specKey] or ''
end

function ns:SetTestPlan(specKey, text)
    ns.db.testPlans[specKey] = text
end

--Ramps of a spec, by name: { spellId, steps }
function ns:GetRamps(specKey)
    return Child(ns.db.ramps, specKey)
end

--Adds the starter ramps of a spec back, replacing ramps with the same name
function ns:RestoreStarterRamps(specKey)
    local ramps = ns:GetRamps(specKey)
    for name, ramp in pairs(ns.starterRamps[specKey] or {}) do
        ramps[name] = Copy(ramp)
    end
end
