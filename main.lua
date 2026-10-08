local _, ns = ...

--Starts the reminders when a raid boss in the boss list is pulled, or when combat starts in testing mode
local function OnFightStart(event, encounterId, encounterName, difficultyId)
    local isRaidBoss = event == "ENCOUNTER_START" and ns.difficulties[difficultyId] ~= nil
    if isRaidBoss and not ns.bosses[encounterId] then
        ns:WriteOutput('No timings for ' .. encounterName .. ', add encounter id ' .. encounterId .. ' to Config/Data.lua to use the addon on this boss')
        return
    end
    local isTest = event == "PLAYER_REGEN_DISABLED" and ns.db.testing.testMode
    if not isRaidBoss and not isTest then
        return
    end
    local specName = ns:GetPlayerSpecName()
    if not specName then
        return
    end
    ns:UpdateCooldowns(specName)
    if isTest then
        ns:BuildFightPlan(specName, ns:GetTestTimings(specName), false)
    else
        ns:BuildFightPlan(specName, ns:GetBossTimings(specName, ns.difficulties[difficultyId].slug, encounterId), true)
    end
    ns:ResetAbilityTimings()
    ns:StartFight(specName, not isTest and encounterId or nil)
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

--Keeps the last readable haste value, since it can be secret during encounters
local hasteTracker = CreateFrame("Frame")
hasteTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
hasteTracker:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
hasteTracker:SetScript("OnEvent", function()
    ns:GetPlayerHaste()
end)
