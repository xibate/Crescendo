--[[Initialization]]--
local _, ns = ...

--Since Midnight addons can't read the combat log, but BigWigs and DBM still work out the boss stages and ability timers
--from Blizzard's encounter timeline and share them with other addons. Phases follow their stages, and the '@ability'
--lines in the timings follow the bars they show for the boss abilities
ns.abilityAnchors = {}
ns.abilityTimings = {}
ns.barSource = nil

--Boss mods usually handle the pull before this addon starts its fight timer, so what they send in the seconds before is kept and replayed once it starts
local earlyEvents = {}
local function KeepForFightStart(replay)
    local now = GetTime()
    while earlyEvents[1] and now - earlyEvents[1]['time'] > 5 do
        table.remove(earlyEvents, 1)
    end
    table.insert(earlyEvents, { ['time'] = now, ['replay'] = replay })
end

function ns:ReplayEarlyBossModEvents()
    local now = GetTime()
    local events = earlyEvents
    earlyEvents = {}
    for _, event in ipairs(events) do
        if now - event['time'] <= 5 then
            event['replay'](now - event['time'])
        end
    end
end

--Starts a phase when BigWigs or DBM report a stage change. Both can be installed, so a stage we are already in is ignored
function ns:StartPhaseFromBossMod(stage)
    if ns:IsSecret(stage) or not tonumber(stage) then
        return
    end
    if not ns.mainTimerData.timerRunning then
        KeepForFightStart(function()
            ns:StartPhaseFromBossMod(stage)
        end)
        return
    end
    if ns.phaseTimerData.currentPhase == ns:PhaseKey(stage) then
        return
    end
    ns:StartPhase(stage)
end

--Bar texts look like 'Spectral Coils (2)', the number is the cast count the boss mod shows
local function SplitBarText(text)
    local name, count = text:match('^(.-)%s*%((%d+)%)%s*$')
    if name then
        return name, tonumber(count)
    end
    return text, nil
end

--Remembers the abilities the boss mods showed bars for, so they can be listed in the options of that boss
function ns:RememberAbility(name, spellId)
    local encounterId = ns.currentEncounterId
    if not encounterId then
        return
    end
    HarreksRampHelperDB.seenAbilities = HarreksRampHelperDB.seenAbilities or {}
    HarreksRampHelperDB.seenAbilities[encounterId] = HarreksRampHelperDB.seenAbilities[encounterId] or {}
    HarreksRampHelperDB.seenAbilities[encounterId][name] = spellId or true
end

--A boss mod started a bar for an ability that lands in 'duration' seconds. If a timings line is tied to it, the steps of that ramp are scheduled from when it lands
function ns:OnBossModBar(source, barKey, text, duration, spellId, count)
    --Bars the boss mods copy straight from Blizzard's timeline can hold secret values, those can't be used
    if ns:IsSecret(barKey) or ns:IsSecret(text) or ns:IsSecret(duration) or ns:IsSecret(spellId) or ns:IsSecret(count) then
        return
    end
    if type(text) ~= 'string' or not tonumber(duration) then
        return
    end
    if not ns.mainTimerData.timerRunning then
        KeepForFightStart(function(elapsed)
            ns:OnBossModBar(source, barKey, text, tonumber(duration) - elapsed, spellId, count)
        end)
        return
    end
    local name, barCount = SplitBarText(text)
    count = tonumber(count) or barCount
    spellId = tonumber(spellId)
    ns:RememberAbility(name, spellId)
    --With both BigWigs and DBM installed, only the first one that shows a bar we use is followed, otherwise every ramp shows twice
    if ns.barSource and ns.barSource ~= source then
        return
    end
    local matches = {}
    for _, anchor in ipairs(ns.abilityAnchors) do
        local sameAbility = (anchor['spellId'] and anchor['spellId'] == spellId) or anchor['name'] == name:lower()
        if sameAbility and (not anchor['counts'] or (count and anchor['counts'][count])) then
            table.insert(matches, anchor)
        end
    end
    if #matches > 0 then
        ns.barSource = source
        ns:ScheduleAbilityTiming(source .. ':' .. tostring(barKey), matches, GetTime() + tonumber(duration))
    end
end

--Creates the reminders for the ramps tied to one bar. Starting the same bar again moves them, without repeating the ones already shown
function ns:ScheduleAbilityTiming(barId, anchors, landsAt)
    local previous = ns.abilityTimings[barId]
    local timing = {
        ['anchors'] = anchors,
        ['landsAt'] = landsAt,
        ['shown'] = previous and previous['shown'] or {},
        ['items'] = {}
    }
    for anchorIndex, anchor in ipairs(anchors) do
        for stepIndex, step in ipairs(ns.assignmentsTable[anchor['type']] or {}) do
            if ns:ShouldUseAssignment(step) then
                local item = ns:CreateAssignment(step)
                item['at'] = landsAt + anchor['shift'] - step['offset']
                item['key'] = anchorIndex .. '-' .. stepIndex
                item['loaded'] = timing['shown'][item['key']] or false
                table.insert(timing['items'], item)
            end
        end
    end
    ns.abilityTimings[barId] = timing
end

--DBM changed the time left on a bar
function ns:OnBossModBarUpdate(source, barKey, remaining)
    if ns:IsSecret(barKey) or ns:IsSecret(remaining) or not tonumber(remaining) then
        return
    end
    if not ns.mainTimerData.timerRunning then
        KeepForFightStart(function(elapsed)
            ns:OnBossModBarUpdate(source, barKey, tonumber(remaining) - elapsed)
        end)
        return
    end
    local barId = source .. ':' .. tostring(barKey)
    local timing = ns.abilityTimings[barId]
    if timing then
        ns:ScheduleAbilityTiming(barId, timing['anchors'], GetTime() + tonumber(remaining))
    end
end

--A bar was stopped. That also happens when the ability goes off, so the reminders due in the next second still show
function ns:OnBossModBarStop(source, barKey)
    if ns:IsSecret(barKey) then
        return
    end
    if not ns.mainTimerData.timerRunning then
        KeepForFightStart(function()
            ns:OnBossModBarStop(source, barKey)
        end)
        return
    end
    local barId = source .. ':' .. tostring(barKey)
    local timing = ns.abilityTimings[barId]
    if timing and timing['landsAt'] - GetTime() > 1 then
        ns.abilityTimings[barId] = nil
    end
end

--Called by the fight timer, shows the reminders tied to boss abilities that are due. Steps that should have started before the bar appeared show right away
function ns:RunAbilityTimings()
    local now = GetTime()
    for _, timing in pairs(ns.abilityTimings) do
        for _, item in ipairs(timing['items']) do
            if not item['loaded'] then
                local timeLeft = item['at'] - now
                local due
                if item['dynamic'] then
                    due = timeLeft >= 0 and ns:ShouldShowDynamic(item, timeLeft)
                else
                    due = timeLeft <= 0
                end
                if due then
                    item['loaded'] = true
                    timing['shown'][item['key']] = true
                    ns:ShowAssignment(item)
                end
            end
        end
    end
end

--Explanation and list of known abilities for the Boss Abilities tab of a boss in the options
function ns:GetAbilityHelpText(encounterId)
    local text = "Instead of a time, a timings line can follow a boss ability that BigWigs or DBM shows a bar for. The ramp is timed so " ..
        "its last step lands when the ability does.\n\n" ..
        "|cffffd100@Spectral Coils|r  every cast\n" ..
        "|cffffd100@Spectral Coils #2,4|r  only the 2nd and 4th cast, the number in brackets on the bar\n" ..
        "|cffffd100@Spectral Coils #2 -3|r  3 seconds before the ability, +3 is 3 seconds after\n" ..
        "|cffffd100@1299010 #2|r  a spell id works instead of the name\n\n" ..
        "Steps that should start before the bar appears show as soon as it does, and the bar has to be enabled in your boss mod.\n\n" ..
        "|cffffd100Abilities seen on this boss|r\n"
    local seen = HarreksRampHelperDB.seenAbilities and HarreksRampHelperDB.seenAbilities[encounterId]
    local names = {}
    for name, spellId in pairs(seen or {}) do
        table.insert(names, type(spellId) == 'number' and (name .. ' (' .. spellId .. ')') or name)
    end
    if #names == 0 then
        return text .. "None yet, pull this boss with BigWigs or DBM and the abilities they show bars for are listed here."
    end
    table.sort(names)
    return text .. table.concat(names, '\n')
end

local bossModHooks = CreateFrame("Frame")
bossModHooks:RegisterEvent("PLAYER_LOGIN")
bossModHooks:SetScript("OnEvent", function()
    if BigWigsLoader and BigWigsLoader.RegisterMessage then
        BigWigsLoader.RegisterMessage(ns, "BigWigs_SetStage", function(_, _, stage)
            ns:StartPhaseFromBossMod(stage)
        end)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StartBar", function(_, module, key, text, time)
            --Pull, break and respawn bars have no key, only boss abilities do. BigWigs identifies its bars by their text
            if module and key ~= nil then
                ns:OnBossModBar('bw', text, text, time, key, nil)
            end
        end)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StopBar", function(_, _, text)
            ns:OnBossModBarStop('bw', text)
        end)
    end
    if DBM and DBM.RegisterCallback then
        DBM:RegisterCallback("DBM_SetStage", function(_, _, _, stage)
            ns:StartPhaseFromBossMod(stage)
        end)
        DBM:RegisterCallback("DBM_TimerBegin", function(_, id, msg, timer, _, _, spellId, _, modId, _, _, _, _, timerCount)
            --Pull, break and LFG timers don't belong to a boss mod
            if modId then
                ns:OnBossModBar('dbm', id, msg, timer, spellId, timerCount)
            end
        end)
        DBM:RegisterCallback("DBM_TimerUpdate", function(_, id, elapsed, total)
            if not ns:IsSecret(elapsed) and not ns:IsSecret(total) and tonumber(elapsed) and tonumber(total) then
                ns:OnBossModBarUpdate('dbm', id, total - elapsed)
            end
        end)
        DBM:RegisterCallback("DBM_TimerStop", function(_, id)
            ns:OnBossModBarStop('dbm', id)
        end)
    end
end)
