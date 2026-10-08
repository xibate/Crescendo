local _, ns = ...

--Starts the reminders when a raid boss in the boss list is pulled, or when combat starts in testing mode
local function OnFightStart(event, encounterId, encounterName, difficultyId)
    local isRaidBoss = event == "ENCOUNTER_START" and ns.difficulties[difficultyId] ~= nil
    if isRaidBoss and not ns.bosses[encounterId] then
        ns:WriteOutput('No plan for ' .. encounterName .. ', add encounter id ' .. encounterId .. ' to Config/Bosses.lua to use the addon on this boss')
        return
    end
    local isTest = event == "PLAYER_REGEN_DISABLED" and ns.db.testing.testMode
    if not isRaidBoss and not isTest then
        return
    end
    local specKey = ns:GetPlayerSpecKey()
    if not specKey then
        return
    end
    if isTest then
        ns:BuildFightPlan(specKey, ns:GetTestPlan(specKey), false)
    else
        ns:BuildFightPlan(specKey, ns:GetPlan(specKey, ns.difficulties[difficultyId].slug, encounterId), true, encounterId)
    end
    ns:ResetAbilityTimings()
    ns:StartFight(specKey, not isTest and encounterId or nil)
    ns:ReplayEarlyBossModEvents()
end

local fightStart = CreateFrame("Frame")
fightStart:RegisterEvent("ENCOUNTER_START")
fightStart:RegisterEvent("PLAYER_REGEN_DISABLED")
fightStart:SetScript("OnEvent", function(_, event, ...)
    OnFightStart(event, ...)
end)

local fightEnd = CreateFrame("Frame")
fightEnd:RegisterEvent("ENCOUNTER_END")
fightEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
fightEnd:SetScript("OnEvent", function(_, event)
    if event == "ENCOUNTER_END" or ns.db.testing.testMode then
        ns:StopFight()
    end
end)

--Haste and spell charges can be secret during encounters, so they are read while they can be
local readableValues = CreateFrame("Frame")
readableValues:RegisterEvent("PLAYER_ENTERING_WORLD")
readableValues:RegisterEvent("PLAYER_REGEN_ENABLED")
readableValues:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
readableValues:SetScript("OnEvent", function()
    ns:GetPlayerHaste()
    local specKey = ns:GetPlayerSpecKey()
    if specKey and ns.db then
        ns:UpdateRechargeTimes(specKey)
    end
end)
