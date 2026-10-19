local _, ns = ...

--The timeline of a recorded pull with a plan: when the boss's abilities went off, when the stages changed and when the
--player's reminders would show, worked out the way a fight does it (see Core/Fight.lua and Core/BossMods.lua) without
--waiting for the replay

--A bar comes back when it is started again after its ability went off, so a new bar for the same key within a second of
--the old one landing means the old one was cast
local LANDED = 1

--The casts of a recording: { at, barAt, name, spellId, count, stage }, following one boss mod like a fight does
local function Casts(record)
    local source
    for _, event in ipairs(record.events) do
        if event.kind == 'bar' then
            source = source or event.source
        end
    end
    local casts, pending, stage = {}, {}, '1'
    local function Land(id)
        local bar = pending[id]
        pending[id] = nil
        if bar and bar.landsAt <= record.duration + 0.5 then
            table.insert(casts, bar)
            bar.at = bar.landsAt
        end
    end
    for _, event in ipairs(record.events) do
        local id = event.key ~= nil and tostring(event.key)
        if event.kind == 'stage' then
            stage = ns:PhaseKey(event.stage)
        elseif event.source == source and id then
            if event.kind == 'bar' then
                local old = pending[id]
                if old and old.landsAt <= event.at + LANDED then
                    Land(id)
                end
                local name, barCount = ns:SplitBarText(event.text)
                pending[id] = {
                    landsAt = event.at + event.duration, barAt = event.at, name = name, spellId = event.spellId,
                    count = event.count or barCount, stage = stage
                }
            elseif event.kind == 'update' and pending[id] then
                pending[id].landsAt = event.at + event.duration
            elseif event.kind == 'stop' and pending[id] then
                if pending[id].landsAt - event.at > LANDED then
                    pending[id] = nil
                else
                    Land(id)
                end
            end
        end
    end
    for id in pairs(pending) do
        Land(id)
    end
    table.sort(casts, function(a, b) return a.at < b.at end)
    return casts
end

--Stage changes of a recording, { at, stage }, skipping a stage reported again
local function Stages(record)
    local stages, current = {}, nil
    for _, event in ipairs(record.events) do
        if event.kind == 'stage' and ns:PhaseKey(event.stage) ~= current then
            current = ns:PhaseKey(event.stage)
            table.insert(stages, { at = event.at, stage = current })
        end
    end
    return stages
end

--When a step shows, given when its ramp lands. A step following charges shows once the charges need all the time left,
--which is at most all charges' recharge before it
local function StepTime(step, landsAt)
    if step.chargesOf then
        return landsAt - ns:GetMaxCharges(step.chargesOf) * ns:GetRechargeTime(step.chargesOf), true
    end
    return landsAt - step.offset, false
end

--{ duration, stages, casts, reminders } of a recording with a plan. Casts have assigned = true when a reminder is tied
--to them, reminders are { at, text, icon, entry, cast (the cast it is for, if any), approximate }
function ns:BuildTimeline(specKey, planText, record, encounterId)
    local timeline = { duration = record.duration, stages = Stages(record), casts = Casts(record), reminders = {} }
    local stepsCache = {}
    local function Steps(entry)
        if stepsCache[entry] == nil then
            stepsCache[entry] = ns:GetEntrySteps(specKey, entry) or false
        end
        return stepsCache[entry] or {}
    end
    --A timed step that would come before its pull or stage is left out, like the fight does, and an ability's step due
    --before its bar showed comes when the bar shows
    local function Add(step, landsAt, earliest, entry, cast)
        if not ns:ShouldUseStep(step) then
            return
        end
        local at, approximate = StepTime(step, landsAt)
        if not cast and not approximate and at < earliest then
            return
        end
        at = math.max(at, earliest)
        if at <= timeline.duration then
            table.insert(timeline.reminders, { at = at, text = step.text, icon = step.icon, entry = entry, cast = cast, approximate = approximate })
        end
    end
    local plan = ns:ParsePlan(planText)
    --Times after the pull, and after each start of a stage while that stage lasts
    for _, timing in ipairs(plan.times) do
        for _, step in ipairs(Steps(timing.entry)) do
            if timing.phase == 'main' then
                Add(step, timing.seconds, 0, timing.entry)
            else
                for index, stage in ipairs(timeline.stages) do
                    local stageEnd = timeline.stages[index + 1] and timeline.stages[index + 1].at or timeline.duration
                    local landsAt = stage.at + timing.seconds
                    if stage.stage == timing.phase and landsAt - step.offset < stageEnd then
                        Add(step, landsAt, stage.at, timing.entry)
                    end
                end
            end
        end
    end
    --Boss abilities, from the bars
    for _, anchor in ipairs(plan.abilities) do
        ns:ResolveAnchor(anchor, encounterId)
        for _, cast in ipairs(timeline.casts) do
            if ns:AnchorMatchesAbility(anchor, cast.name, cast.spellId) and ns:AnchorMatchesCast(anchor, cast.count) and
                ns:AnchorMatchesPhase(anchor, cast.stage) then
                local steps = Steps(anchor.entry)
                if #steps > 0 then
                    cast.assigned = true
                end
                for _, step in ipairs(steps) do
                    Add(step, cast.at + anchor.shift, cast.barAt, anchor.entry, cast)
                end
            end
        end
    end
    table.sort(timeline.reminders, function(a, b) return a.at < b.at end)
    return timeline
end
