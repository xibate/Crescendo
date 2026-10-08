local _, ns = ...

--Current cooldown of the spec's spells with talents and haste, worked out at the start of each fight
ns.cooldowns = {}

--Name of the player's spec if the addon supports it
function ns:GetPlayerSpecName()
    local specId
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local index = C_SpecializationInfo.GetSpecialization()
        specId = index and C_SpecializationInfo.GetSpecializationInfo(index)
    else
        local index = GetSpecialization()
        specId = index and GetSpecializationInfo(index)
    end
    return ns.specs[specId]
end

--Haste can be secret during encounters, so the last readable value is kept and used instead
function ns:GetPlayerHaste()
    local haste = GetHaste()
    if ns:IsSecret(haste) then
        return ns.lastKnownHaste or 0
    end
    ns.lastKnownHaste = haste
    return haste
end

--IsPlayerSpell moved to C_SpellBook, the old global only exists as a deprecated fallback
function ns:IsSpellKnown(spellId)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellId, Enum.SpellBookSpellBank.Player)
    end
    return IsPlayerSpell(spellId)
end

function ns:UpdateCooldowns(specName)
    local haste = ns:GetPlayerHaste() / 100
    ns.cooldowns = {}
    for spellId, spell in pairs(ns.specData[specName].spells) do
        local cd = spell.cd
        for talent, change in pairs(spell.talents or {}) do
            if ns:IsSpellKnown(talent) then
                cd = cd + change
            end
        end
        if spell.haste then
            cd = tonumber(string.format('%.1f', cd / (1 + haste)))
        end
        ns.cooldowns[spellId] = cd
    end
end

--Current cooldown of a spell, or its base cooldown before the first fight
function ns:GetCooldown(specName, spellId)
    return ns.cooldowns[spellId] or ns.specData[specName].spells[spellId].cd
end

function ns:GetRampSteps(specName)
    return ns.specData[specName].rampSteps(function(spellId)
        return ns:GetCooldown(specName, spellId)
    end)
end

--All spells of a spec that can be in an MRT note, spell id => ramp or spell name
function ns:GetSpellList(specName)
    local spellList = {}
    for _, group in ipairs({ 'cooldowns', 'ramps', 'utilities' }) do
        for spellId, name in pairs(ns.specData[specName][group]) do
            spellList[spellId] = name
        end
    end
    return spellList
end

--The reminder steps of everything turned on for the spec, by ramp or spell name. Cooldowns and utilities get a countdown
--and a reminder at their time, and are left out when the spell no longer exists
function ns:GetSteps(specName)
    local steps = {}
    for name, rampSteps in pairs(ns:GetRampSteps(specName)) do
        if ns:IsEnabled(specName, name) then
            steps[name] = rampSteps
        end
    end
    for _, group in ipairs({ 'cooldowns', 'utilities' }) do
        for spellId, name in pairs(ns.specData[specName][group]) do
            local spellInfo = C_Spell.GetSpellInfo(spellId)
            if ns:IsEnabled(specName, name) and spellInfo and spellInfo.iconID then
                steps[name] = {
                    { text = name .. ' Soon', icon = spellInfo.iconID, offset = ns.db.options.timerDuration, countdown = true },
                    { text = name, icon = spellInfo.iconID, offset = 0 }
                }
            end
        end
    end
    return steps
end
