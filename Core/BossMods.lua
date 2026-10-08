local _, ns = ...

--Since Midnight addons can't read the combat log, but BigWigs and DBM still work out the boss stages and ability timers
--from Blizzard's encounter timeline and share them with other addons. Phases follow their stages, and the '@ability'
--lines in the timings follow the bars they show for the boss abilities.

--Ability lines of the current fight (see Core/PlanText.lua), each with the ramp or spell name it belongs to as 'entry'
ns.abilityAnchors = {}
--Reminders tied to a boss mod bar, by bar id: { anchors, landsAt, reminders, shown } with reminder times in GetTime() seconds
local abilityTimings = {}
--The boss mod followed this fight, the first one to show a matching bar
local barSource = nil

function ns:ResetAbilityTimings()
    abilityTimings = {}
    barSource = nil
end

--Boss mods usually handle the pull before this addon starts its fight, so what they send in the seconds before is kept
--and replayed once it starts
local earlyEvents = {}

local function KeepForFightStart(replay)
    local now = GetTime()
    while earlyEvents[1] and now - earlyEvents[1].time > 5 do
        table.remove(earlyEvents, 1)
    end
    table.insert(earlyEvents, { time = now, replay = replay })
end

function ns:ReplayEarlyBossModEvents()
    local now = GetTime()
    local events = earlyEvents
    earlyEvents = {}
    for _, event in ipairs(events) do
        if now - event.time <= 5 then
            event.replay(now - event.time)
        end
    end
end

--A boss mod reported a stage. With both installed the second report of the same stage is ignored
function ns:StartPhaseFromBossMod(stage)
    if ns:IsSecret(stage) or not tonumber(stage) then
        return
    end
    if not ns.fight.running then
        KeepForFightStart(function()
            ns:StartPhaseFromBossMod(stage)
        end)
        return
    end
    if ns.fight.phase ~= ns:PhaseKey(stage) then
        ns:StartPhase(stage)
    end
end

--Bar texts look like 'Spectral Coils (2)', the number is the cast count the boss mod shows
local function SplitBarText(text)
    local name, count = text:match('^(.-)%s*%((%d+)%)%s*$')
    if name then
        return name, tonumber(count)
    end
    return text, nil
end

--Remembers the abilities the boss mods showed bars for, so the options can list them for that boss
local function RememberAbility(name, spellId)
    local encounterId = ns.fight.encounterId
    if encounterId then
        ns.db.seenAbilities[encounterId] = ns.db.seenAbilities[encounterId] or {}
        ns.db.seenAbilities[encounterId][name] = spellId or true
    end
end

--The spell ids and names an ability line can show up under on a boss mod bar. BigWigs names its bars after the game's
--(localized) spell name and DBM can use other spell ids, so a line by name also matches the ids the boss's ability list
--has for that name, and a line by id also matches the names of that spell
function ns:ResolveAnchor(anchor, encounterId)
    anchor.spellIds = {}
    anchor.names = {}
    local function AddSpell(spellId)
        anchor.spellIds[spellId] = true
        local info = C_Spell.GetSpellInfo(spellId)
        if info and info.name then
            anchor.names[info.name:lower()] = true
        end
    end
    if anchor.spellId then
        AddSpell(anchor.spellId)
    else
        anchor.names[anchor.name] = true
    end
    for _, ability in ipairs(ns.bossAbilities[encounterId] or {}) do
        if ability.spellId == anchor.spellId or ability.name:lower() == anchor.name then
            AddSpell(ability.spellId)
            anchor.names[ability.name:lower()] = true
        end
    end
end

local function MatchingAnchors(name, spellId, count)
    local matches = {}
    for _, anchor in ipairs(ns.abilityAnchors) do
        local sameAbility = (spellId and anchor.spellIds[spellId]) or anchor.names[name:lower()]
        if sameAbility and (not anchor.counts or (count and anchor.counts[count])) then
            table.insert(matches, anchor)
        end
    end
    return matches
end

--Creates the reminders of the ramps tied to one bar, timed so they land when the ability does. Starting the same bar
--again moves them, without repeating the ones already shown
local function ScheduleAbilityTiming(barId, anchors, landsAt)
    local previous = abilityTimings[barId]
    local timing = {
        anchors = anchors,
        landsAt = landsAt,
        shown = previous and previous.shown or {},
        reminders = {}
    }
    for anchorIndex, anchor in ipairs(anchors) do
        for stepIndex, step in ipairs(ns.steps[anchor.entry] or {}) do
            if ns:ShouldUseStep(step) then
                local reminder = ns:CreateReminder(step, landsAt + anchor.shift - step.offset)
                reminder.key = anchorIndex .. '-' .. stepIndex
                reminder.shown = timing.shown[reminder.key] or false
                table.insert(timing.reminders, reminder)
            end
        end
    end
    abilityTimings[barId] = timing
end

--A boss mod started a bar for an ability that lands in 'duration' seconds
function ns:OnBossModBar(source, barKey, text, duration, spellId, count)
    --Bars the boss mods copy straight from Blizzard's timeline can hold secret values, those can't be used
    if ns:IsSecret(barKey) or ns:IsSecret(text) or ns:IsSecret(duration) or ns:IsSecret(spellId) or ns:IsSecret(count) then
        return
    end
    if type(text) ~= 'string' or not tonumber(duration) then
        return
    end
    if not ns.fight.running then
        KeepForFightStart(function(elapsed)
            ns:OnBossModBar(source, barKey, text, tonumber(duration) - elapsed, spellId, count)
        end)
        return
    end
    local name, barCount = SplitBarText(text)
    spellId = tonumber(spellId)
    RememberAbility(name, spellId)
    --With both BigWigs and DBM installed only one is followed, otherwise every reminder shows twice
    if barSource and barSource ~= source then
        return
    end
    local matches = MatchingAnchors(name, spellId, tonumber(count) or barCount)
    if #matches > 0 then
        barSource = source
        ScheduleAbilityTiming(source .. ':' .. tostring(barKey), matches, GetTime() + tonumber(duration))
    end
end

--DBM changed the time left on a bar
function ns:OnBossModBarUpdate(source, barKey, remaining)
    if ns:IsSecret(barKey) or ns:IsSecret(remaining) or not tonumber(remaining) then
        return
    end
    if not ns.fight.running then
        KeepForFightStart(function(elapsed)
            ns:OnBossModBarUpdate(source, barKey, tonumber(remaining) - elapsed)
        end)
        return
    end
    local barId = source .. ':' .. tostring(barKey)
    if abilityTimings[barId] then
        ScheduleAbilityTiming(barId, abilityTimings[barId].anchors, GetTime() + tonumber(remaining))
    end
end

--A bar was stopped. That also happens when the ability goes off, so reminders due within a second still show
function ns:OnBossModBarStop(source, barKey)
    if ns:IsSecret(barKey) then
        return
    end
    if not ns.fight.running then
        KeepForFightStart(function()
            ns:OnBossModBarStop(source, barKey)
        end)
        return
    end
    local barId = source .. ':' .. tostring(barKey)
    local timing = abilityTimings[barId]
    if timing and timing.landsAt - GetTime() > 1 then
        abilityTimings[barId] = nil
    end
end

--Shows the reminders tied to boss abilities that are due. Steps that should have started before the bar appeared show right away
function ns:ShowDueAbilityReminders(now)
    for _, timing in pairs(abilityTimings) do
        for _, reminder in ipairs(timing.reminders) do
            if not reminder.shown and ns:IsDue(reminder, reminder.at - now) then
                reminder.shown = true
                timing.shown[reminder.key] = true
                ns:ShowReminder(reminder)
            end
        end
    end
end

--The abilities BigWigs or DBM showed bars for on a boss, for the Plan tab
function ns:GetSeenAbilitiesText(encounterId)
    local names = {}
    for name, spellId in pairs(ns.db.seenAbilities[encounterId] or {}) do
        table.insert(names, type(spellId) == 'number' and (name .. ' (' .. spellId .. ')') or name)
    end
    if #names == 0 then
        return "None yet. Pull this boss with BigWigs or DBM and the abilities they show bars for are listed here, to use in @ lines."
    end
    table.sort(names)
    return table.concat(names, '\n')
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
