local _, ns = ...

--Starts the reminders when a raid boss in the boss list is pulled
local function OnEncounterStart(encounterId, encounterName, difficultyId)
    difficultyId = ns.difficultyAliases[difficultyId] or difficultyId
    if not ns.difficulties[difficultyId] then
        return
    end
    if not ns.bosses[encounterId] then
        ns:WriteOutput('No plan for ' .. encounterName .. ', add encounter id ' .. encounterId .. ' to Config/Bosses.lua to use the addon on this boss')
        return
    end
    local specKey = ns:GetPlayerSpecKey()
    if not specKey then
        return
    end
    local diffSlug = ns.difficulties[difficultyId].slug
    ns:BuildFightPlan(specKey, ns:GetPlan(specKey, diffSlug, encounterId), true, encounterId)
    ns:ResetAbilityTimings()
    ns:StartFight(specKey, encounterId)
    ns:StartRecording(encounterId, diffSlug)
    ns:ReplayEarlyBossModEvents()
end

local encounter = CreateFrame("Frame")
encounter:RegisterEvent("ENCOUNTER_START")
encounter:RegisterEvent("ENCOUNTER_END")
encounter:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        OnEncounterStart(...)
    elseif ns.fight.running and not ns.fight.test then
        ns:StopRecording()
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Crescendo" then
        ns:InitDatabase()
        ns:SetUpCommands()
    end
end)
