local _, ns = ...

local DATABASE_VERSION = 3

--Saved settings. options, plans, history and ramps belong to a profile: profiles[name] holds them, profileKeys["Name -
--Realm"] says which profile a character uses ('Default' when it says nothing), and while the game runs they are also
--at the top of CrescendoDB for the profile in use (taken out again at logout so they aren't saved twice):
-- options        display, text to speech and MRT note settings
-- plans          plans[spec][difficulty slug][encounter id] = plan text, see Core/PlanText.lua
-- history        history[spec][difficulty slug][encounter id] = earlier versions of the plan, newest first
-- ramps          ramps[spec][ramp name] = { spellId = spell MRT notes use, steps = steps text, see Core/Ramps.lua }
--The rest is for every profile:
-- testPlans      testPlans[spec] = plan text of the old testing mode, no longer used
-- seenAbilities  seenAbilities[encounter id][ability name] = spell id, the abilities boss mods showed bars for
-- cooldowns      cooldowns[spell id] = cooldown in seconds, seen when it could be read, see Core/Cooldowns.lua
-- recordings     recordings[encounter id][difficulty slug] = the longest recorded pull, see Core/Test.lua
-- ui             what is selected in the window
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
        timerDuration = 3,
        snapToGrid = true,
        hideOnCooldown = false,
        sound = 'none',
        soundOn = 'all',
        followRaid = true,
        readyCheck = true,
        nextUp = true,
        nextUpCount = 3,
        nextUpX = 0,
        nextUpY = -150,
        spokenCountdown = false,
        countdownFrom = 5,
        review = true,
        displayStyle = 'icon',
        barWidth = 260,
        accentSource = 'ellesmere',
        accentColor = { r = 0.05, g = 0.82, b = 0.62 },
        windowScale = 1
    },
    plans = {},
    testPlans = {},
    ramps = {},
    seenAbilities = {},
    cooldowns = {},
    recordings = {},
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
    local info = spellId and C_Spell.GetSpellInfo(spellId)
    --Spells removed in Midnight keep their old name, the pull then says it is skipped
    return info and info.name or oldName
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

--Starter ramps saved before version 3 weren't checked against Midnight. Unchanged ones are removed, then the current
--starter ramps are added where a spec doesn't have a ramp with that name
local function UpdateStarterRamps(db)
    for specKey, outdated in pairs(ns.outdatedStarterRamps) do
        local ramps = Child(db.ramps, specKey)
        for name, steps in pairs(outdated) do
            if type(ramps[name]) == 'table' and ramps[name].steps == steps then
                ramps[name] = nil
            end
        end
    end
    for specKey, starters in pairs(ns.starterRamps) do
        local ramps = Child(db.ramps, specKey)
        for name, ramp in pairs(starters) do
            if ramps[name] == nil then
                ramps[name] = Copy(ramp)
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Profiles
------------------------------------------------------------------------------------------------------------------------

local PROFILE_PARTS = { 'options', 'plans', 'history', 'ramps' }
local DEFAULT_PROFILE = 'Default'

--The character, like profile keys of other addons: 'Name - Realm'
local function CharacterKey()
    local realm = GetRealmName and GetRealmName() or ''
    return (UnitName("player") or "?") .. (realm ~= '' and (" - " .. realm) or "")
end

--Fills in what a profile is missing: the default options and the starter ramps
local function FillProfile(profile)
    for _, part in ipairs(PROFILE_PARTS) do
        if type(profile[part]) ~= 'table' then
            profile[part] = {}
        end
    end
    for key, value in pairs(defaults.options) do
        if profile.options[key] == nil then
            profile.options[key] = Copy(value)
        end
    end
    profile.options.toggleDisplay = false
    for _, spec in pairs(ns.specs) do
        if profile.ramps[spec.key] == nil then
            profile.ramps[spec.key] = Copy(ns.starterRamps[spec.key] or {})
        end
    end
    return profile
end

--The first time, the settings there were become the Default profile, and a character that saved its own plans gets a
--profile of its own with them
local function SetUpProfiles(db)
    if type(db.profiles) ~= 'table' or next(db.profiles) == nil then
        db.profiles = { [DEFAULT_PROFILE] = { options = db.options, plans = db.plans, ramps = db.ramps,
            history = type(db.history) == 'table' and db.history or {} } }
    end
    if type(db.profileKeys) ~= 'table' then
        db.profileKeys = {}
    end
    local key = CharacterKey()
    local character = ns.characterDb
    if character.perCharacter and type(character.plans) == 'table' and not db.profileKeys[key] then
        local base = FillProfile(db.profiles[DEFAULT_PROFILE] or {})
        db.profiles[key] = { options = Copy(base.options), ramps = Copy(base.ramps), plans = character.plans,
            history = type(character.history) == 'table' and character.history or {} }
        db.profileKeys[key] = key
    end
    character.perCharacter, character.plans, character.history = nil, nil, nil
    local name = db.profileKeys[key]
    if not (name and db.profiles[name]) then
        name = DEFAULT_PROFILE
    end
    ns:UseProfile(name)
end

--Switches this character to a profile, creating it when it doesn't exist
function ns:UseProfile(name)
    local db = ns.db
    local profile = FillProfile(db.profiles[name] or {})
    db.profiles[name] = profile
    db.profileKeys[CharacterKey()] = name ~= DEFAULT_PROFILE and name or nil
    for _, part in ipairs(PROFILE_PARTS) do
        db[part] = profile[part]
    end
    ns.profileName = name
end

function ns:CurrentProfile()
    return ns.profileName
end

function ns:ProfileNames()
    local names = {}
    for name in pairs(ns.db.profiles) do
        table.insert(names, name)
    end
    table.sort(names, function(a, b)
        if (a == DEFAULT_PROFILE) ~= (b == DEFAULT_PROFILE) then
            return a == DEFAULT_PROFILE
        end
        return a:lower() < b:lower()
    end)
    return names
end

--How many characters use a profile
function ns:ProfileUsers(name)
    local count = 0
    for _, used in pairs(ns.db.profileKeys) do
        count = count + (used == name and 1 or 0)
    end
    if name == DEFAULT_PROFILE then
        return nil
    end
    return count
end

--A new profile with the default settings and starter ramps, which this character then uses. Returns nil and why when
--the name can't be used
function ns:CreateProfile(name)
    name = (name or ''):match('^%s*(.-)%s*$')
    if name == '' then
        return nil, "Type a name for the profile"
    end
    if ns.db.profiles[name] then
        return nil, "There is a profile called " .. name .. " already"
    end
    ns.db.profiles[name] = FillProfile({})
    ns:UseProfile(name)
    return true
end

--Replaces the profile in use with a copy of another profile's plans, ramps and settings
function ns:CopyProfile(from)
    local source = ns.db.profiles[from]
    if not source or from == ns.profileName then
        return false
    end
    local profile = ns.db.profiles[ns.profileName]
    for _, part in ipairs(PROFILE_PARTS) do
        profile[part] = Copy(source[part])
    end
    ns:UseProfile(ns.profileName)
    return true
end

--Deletes a profile that isn't in use; characters that used it go back to Default
function ns:DeleteProfile(name)
    if name == ns.profileName or name == DEFAULT_PROFILE or not ns.db.profiles[name] then
        return false
    end
    ns.db.profiles[name] = nil
    for character, used in pairs(ns.db.profileKeys) do
        if used == name then
            ns.db.profileKeys[character] = nil
        end
    end
    return true
end

--Puts the profile in use back to the default settings and starter ramps, without plans
function ns:ResetProfile()
    ns.db.profiles[ns.profileName] = FillProfile({})
    ns:UseProfile(ns.profileName)
end

--The profile's parts are taken out of the top of the saved settings at logout, so they are saved once, in the profile
function ns:BeforeLogout()
    if not ns.db then
        return
    end
    for _, part in ipairs(PROFILE_PARTS) do
        ns.db[part] = nil
    end
end

--Creates the saved settings or fills in what is missing. Only nil is replaced, so options turned off stay off
function ns:InitDatabase()
    --The addon was called Zynx Ramp Helper before, its settings move over once
    if type(CrescendoDB) ~= 'table' and type(ZynxRampHelperDB) == 'table' then
        CrescendoDB = ZynxRampHelperDB
    end
    ZynxRampHelperDB = nil
    if type(CrescendoDB) ~= 'table' then
        CrescendoDB = {}
    end
    local db = CrescendoDB
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
    if (db.version or 1) < 3 then
        UpdateStarterRamps(db)
    end
    db.version = DATABASE_VERSION
    ns.db = db
    if type(CrescendoCharacterDB) ~= 'table' then
        CrescendoCharacterDB = {}
    end
    ns.characterDb = CrescendoCharacterDB
    SetUpProfiles(db)
end

--Puts the display, text to speech and MRT note options back to their defaults
function ns:ResetOptions()
    for key, value in pairs(defaults.options) do
        ns.db.options[key] = Copy(value)
    end
end

--The plans of the profile in use
local function Plans()
    return ns.db.plans
end

--Earlier versions of each plan, newest first, kept where the plans are kept
local HISTORY_SIZE = 10

local function History(specKey, diffSlug, encounterId)
    if type(ns.db.history) ~= 'table' then
        ns.db.history = {}
    end
    return Child(Child(Child(ns.db.history, specKey), diffSlug), tostring(encounterId))
end

--Keeps a plan as it is before a change: { time, text, reason }. With throttle, not when a copy for the same reason was kept
--that many seconds ago, so edit after edit keeps one copy
function ns:BackupPlan(specKey, diffSlug, encounterId, reason, throttle)
    local text = ns:GetPlan(specKey, diffSlug, encounterId)
    if not text:find('%S') then
        return
    end
    local history = History(specKey, diffSlug, encounterId)
    local newest = history[1]
    if newest and (newest.text == text or (throttle and newest.reason == reason and time() - newest.time < throttle)) then
        return
    end
    table.insert(history, 1, { time = time(), text = text, reason = reason })
    while #history > HISTORY_SIZE do
        table.remove(history)
    end
end

function ns:GetPlanHistory(specKey, diffSlug, encounterId)
    return History(specKey, diffSlug, encounterId)
end

--Puts an earlier version of a plan back, keeping the plan it replaces
function ns:RestorePlan(specKey, diffSlug, encounterId, version)
    ns:BackupPlan(specKey, diffSlug, encounterId, "Before restoring an earlier version")
    ns:SetPlan(specKey, diffSlug, encounterId, version.text)
end

function ns:GetPlan(specKey, diffSlug, encounterId)
    return Child(Child(Plans(), specKey), diffSlug)[tostring(encounterId)] or ''
end

function ns:SetPlan(specKey, diffSlug, encounterId, text)
    Child(Child(Plans(), specKey), diffSlug)[tostring(encounterId)] = text
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
