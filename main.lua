--[[Initialization]]--
local _, ns = ...
local next = next
--Timer Variables
ns.mainTimerData = {
    currentTimer = 0,
    startTime = nil,
    timerRunning = false,
    runningTimer = nil
}
ns.phaseTimerData = {
    currentPhase = nil,
    currentTimer = 0,
    startTime = nil,
    timerRunning = false,
    runningTimer = nil,
    phaseActivations = {},
    phaseTriggerCounter = {}
}
--Assignment Variables
ns.specName = nil
ns.specSupported = false
ns.fightAssignments = {}
ns.frames = {}
--Midnight (12.0) removed the combat log from addons, registering for it gets the addon blocked
ns.combatLogAvailable = select(4, GetBuildInfo()) < 120000
--Timer Frames
ns.phaseEventsTrigger = CreateFrame("Frame") --Frame that handles phase changing
ns.phaseEventsTrigger:SetScript("OnEvent", function()
    local _, subEvent, _, _, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    for phase, trigger in pairs(ns.phaseTimerData.phaseActivations) do
        if subEvent == ns.phaseEvents[trigger.event] and spellId == tonumber(trigger.spell) then
            if ns.phaseTimerData.phaseTriggerCounter[phase] then
                ns.phaseTimerData.phaseTriggerCounter[phase] = ns.phaseTimerData.phaseTriggerCounter[phase] + 1
            else
                ns.phaseTimerData.phaseTriggerCounter[phase] = 1
            end
            if ns.phaseTimerData.phaseTriggerCounter[phase] == tonumber(ns.phaseTimerData.phaseActivations[phase].count) then
                ns:StartPhase(phase)
            end
        end
    end
end)

local startTimer = CreateFrame("Frame") --The frame that runs the functions on encounter start
startTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
startTimer:RegisterEvent("ENCOUNTER_START")
startTimer:SetScript("OnEvent", function(_, event, encounterId, encounterName, difficultyId)
    if event == "ENCOUNTER_START" and ns.difficulties[difficultyId] and not ns.bosses[encounterId] then
        ns:WriteOutput('No timings for ' .. encounterName .. ', add encounter id ' .. encounterId .. ' to Config/Data.lua to use the addon on this boss')
    end
    if (event == "ENCOUNTER_START" and ns.difficulties[difficultyId] and ns.bosses[encounterId]) or (event == "PLAYER_REGEN_DISABLED" and HarreksRampHelperDB.testing.testMode) then
        ns:SetPlayerSpec()
        if ns.specSupported then
            ns:SetupTimings(event, encounterId, difficultyId)
            if encounterId and next(ns.bosses[encounterId].phases[ns.difficulties[difficultyId].slug]) ~= nil then
                local bossPhaseChanges = ns.bosses[encounterId].phases[ns.difficulties[difficultyId].slug]
                ns:SetupPhaseChanges(bossPhaseChanges)
            end
            ns:StartTimer()
        end
    end
end)

local stopTimer = CreateFrame("Frame") --Frame that stops the timer on encounter end
stopTimer:RegisterEvent("ENCOUNTER_END")
stopTimer:RegisterEvent("PLAYER_REGEN_ENABLED")
stopTimer:SetScript("OnEvent", function(_, event)
    if event == "ENCOUNTER_END" or (event == "PLAYER_REGEN_ENABLED" and HarreksRampHelperDB.testing.testMode) then
        ns:StopTimer()
    end
end)

local bossModStages = CreateFrame("Frame") --Follows the stages BigWigs and DBM detect, since addons can't see phase changes in the combat log anymore
bossModStages:RegisterEvent("PLAYER_LOGIN")
bossModStages:SetScript("OnEvent", function()
    if BigWigsLoader and BigWigsLoader.RegisterMessage then
        BigWigsLoader.RegisterMessage(ns, "BigWigs_SetStage", function(_, _, stage)
            ns:StartPhaseFromBossMod(stage)
        end)
    end
    if DBM and DBM.RegisterCallback then
        DBM:RegisterCallback("DBM_SetStage", function(_, _, _, stage)
            ns:StartPhaseFromBossMod(stage)
        end)
    end
end)

local hasteTracker = CreateFrame("Frame") --Keeps the last readable haste value, since it can be secret during encounters
hasteTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
hasteTracker:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
hasteTracker:SetScript("OnEvent", function()
    ns:GetPlayerHaste()
end)
