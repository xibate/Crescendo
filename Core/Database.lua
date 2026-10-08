local _, ns = ...

--Saved settings. Timings are stored per spec as db[specName][difficulty slug][encounter id][ramp or spell name] = timings text,
--and the test timers as db[specName].testTimers[ramp or spell name]
local defaults = {
    testing = {
        testMode = false
    },
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
        --Which ramps, cooldowns and utilities are turned on, per spec. Anything not in here is on
        specs = {}
    },
    import = {},
    --Boss abilities BigWigs or DBM showed bars for, per encounter id
    seenAbilities = {}
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
    db.import = {}
    ns.db = db
end

--Puts the display, text to speech and other options back to their defaults. Which spells are turned on is kept
function ns:ResetOptions()
    for key, value in pairs(defaults.options) do
        if key ~= 'specs' then
            ns.db.options[key] = Copy(value)
        end
    end
end

local function Child(parent, key)
    if type(parent[key]) ~= 'table' then
        parent[key] = {}
    end
    return parent[key]
end

--Timings texts of one boss for a spec, by ramp or spell name
function ns:GetBossTimings(specName, diffSlug, encounterId)
    return Child(Child(Child(ns.db, specName), diffSlug), tostring(encounterId))
end

--Test timings texts of a spec, by ramp or spell name
function ns:GetTestTimings(specName)
    return Child(Child(ns.db, specName), 'testTimers')
end

function ns:IsEnabled(specName, name)
    return Child(ns.db.options.specs, specName)[name] ~= false
end

function ns:SetEnabled(specName, name, enabled)
    Child(ns.db.options.specs, specName)[name] = enabled
end
