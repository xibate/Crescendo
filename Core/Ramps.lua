local _, ns = ...

--A ramp is written as one step per line: '<when> | <text> | <option> | ...'
--  when     seconds before the ramp lands ('20'), global cooldowns before it ('12gcd', shortened by haste), or
--           'charges <spell>' to show the step once that spell's charges need all the time left to come back
--  text     what is shown and spoken
--  options  'setup' marks a setup step, 'countdown' shows a countdown on the icon, 'icon <spell>' picks the icon
--           and 'say <text>' speaks something else than the text. Spells can be an id or a name
--Without an icon option a step uses the icon of the spell named in its text, or else the ramp's spell

local QUESTION_MARK_ICON = 134400
local DEFAULT_RECHARGE = 30

--Recharge time of charged spells, kept while it can be read since it can be secret during encounters
ns.rechargeTimes = {}

local function Trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function SpellIcon(spell)
    if spell == nil or spell == '' then
        return nil
    end
    local info = C_Spell.GetSpellInfo(spell)
    return info and info.iconID
end

local function ParseWhen(step, when)
    local lower = when:lower()
    local seconds = lower:match('^(%d+%.?%d*)s?$')
    local gcds = lower:match('^(%d+%.?%d*)%s*gcds?$')
    if seconds then
        step.seconds = tonumber(seconds)
    elseif gcds then
        step.gcds = tonumber(gcds)
    elseif lower:find('^charges%s') then
        local spell = Trim(when:sub(8))
        step.chargesOf = tonumber(spell) or spell
    else
        return false
    end
    return true
end

--Reads a ramp's steps text. Returns the steps, or nil and what is wrong
function ns:ParseRampSteps(text)
    local steps = {}
    for line in ns:Lines(text) do
        if not line:find('^%s*$') then
            local parts = {}
            for part in (line .. '|'):gmatch('([^|]*)|') do
                table.insert(parts, Trim(part))
            end
            local step = { text = parts[2] }
            if not step.text or step.text == '' then
                return nil, "'" .. line .. "' has no text, write steps like: 12gcd | Start ramp"
            end
            if not ParseWhen(step, parts[1]) then
                return nil, "'" .. parts[1] .. "' isn't a time, use seconds like 20, global cooldowns like 12gcd or charges <spell>"
            end
            for index = 3, #parts do
                local option, value = parts[index]:match('^(%a+)%s*(.-)$')
                option = option and option:lower()
                if option == 'setup' then
                    step.prerequisite = true
                elseif option == 'countdown' then
                    step.countdown = true
                elseif option == 'icon' and value ~= '' then
                    step.iconSpell = tonumber(value) or value
                elseif option == 'say' and value ~= '' then
                    step.tts = value
                elseif parts[index] ~= '' then
                    return nil, "'" .. parts[index] .. "' isn't an option, use setup, countdown, icon <spell> or say <text>"
                end
            end
            table.insert(steps, step)
        end
    end
    return steps
end

--Global cooldown with the player's haste
function ns:GetGcd()
    return math.max(0.75, tonumber(string.format('%.1f', 1.5 / (1 + ns:GetPlayerHaste() / 100))))
end

--A ramp of a spec by name, ignoring case
function ns:FindRamp(specKey, name)
    local lower = name:lower()
    for rampName, ramp in pairs(ns:GetRamps(specKey)) do
        if rampName:lower() == lower then
            return ramp, rampName
        end
    end
end

function ns:GetRampNames(specKey)
    local names = {}
    for name in pairs(ns:GetRamps(specKey)) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--Spells whose charges a spec's ramps follow
local function ChargedSpells(specKey)
    local spells = {}
    for _, ramp in pairs(ns:GetRamps(specKey)) do
        for _, step in ipairs(ns:ParseRampSteps(ramp.steps) or {}) do
            if step.chargesOf then
                spells[step.chargesOf] = true
            end
        end
    end
    return spells
end

--Keeps the recharge time of the spells the ramps follow while it can be read
function ns:UpdateRechargeTimes(specKey)
    for spell in pairs(ChargedSpells(specKey)) do
        local charges = C_Spell.GetSpellCharges(spell)
        if charges and not ns:IsSecret(charges.cooldownDuration) and charges.cooldownDuration and charges.cooldownDuration > 0 then
            ns.rechargeTimes[spell] = charges.cooldownDuration
        end
    end
end

function ns:GetRechargeTime(spell)
    return ns.rechargeTimes[spell] or DEFAULT_RECHARGE
end

--The reminder steps of a plan entry, with offsets in seconds before the entry's time. A ramp gives its steps, any other
--spell (by name or id) a countdown and a reminder at its time. Nil when the name is neither
function ns:GetEntrySteps(specKey, name)
    local ramp = ns:FindRamp(specKey, name)
    if ramp then
        local gcd = ns:GetGcd()
        local rampIcon = SpellIcon(ramp.spellId) or SpellIcon(name)
        local steps = {}
        for _, step in ipairs(ns:ParseRampSteps(ramp.steps) or {}) do
            table.insert(steps, {
                text = step.text,
                tts = step.tts,
                prerequisite = step.prerequisite,
                countdown = step.countdown,
                chargesOf = step.chargesOf,
                offset = step.seconds or (step.gcds and step.gcds * gcd) or 0,
                icon = SpellIcon(step.iconSpell) or SpellIcon(step.text) or rampIcon or QUESTION_MARK_ICON
            })
        end
        return steps
    end
    local info = C_Spell.GetSpellInfo(tonumber(name) or name)
    if info and info.iconID then
        local spellName = info.name or name
        return {
            { text = spellName .. ' Soon', icon = info.iconID, offset = ns.db.options.timerDuration, countdown = true },
            { text = spellName, icon = info.iconID, offset = 0 }
        }
    end
end
