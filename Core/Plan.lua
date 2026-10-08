local _, ns = ...

--Reminders of the current fight: ns.plan[phase key] lists the reminders timed from the pull ('main') or from the start of
--a phase, as { at = seconds, text, icon, ..., shown }. ns.steps has the steps of every ramp or spell in the plan, by name,
--and false for names that are neither
ns.plan = {}
ns.steps = {}

--In setup steps only mode the final press of a ramp is left out
function ns:ShouldUseStep(step)
    return not ns.db.options.preReqsOnly or step.prerequisite
end

function ns:CreateReminder(step, at)
    return {
        at = at,
        text = step.text,
        icon = step.icon,
        tts = step.tts,
        countdown = step.countdown,
        chargesOf = step.chargesOf,
        shown = false
    }
end

--Plan lines from the MRT notes the options say to read, nil when no note is read
local function ReadMrtNotes(specKey)
    local options = ns.db.options
    if not options.readFromNote and not options.mrtPersonalNote then
        return nil
    end
    local note = _G.VMRT and _G.VMRT.Note
    if not note then
        ns:WriteOutput("Reading times from MRT notes is turned on, but MRT isn't loaded.")
        return nil
    end
    local texts = {}
    if options.readFromNote then
        table.insert(texts, note.Text1 or '')
    end
    if options.mrtPersonalNote then
        table.insert(texts, note.SelfText or '')
    end
    return ns:NoteToPlan(table.concat(texts, '\n'), specKey)
end

--Builds the reminders of a fight from a plan. With MRT notes turned on, the times come from the notes and the boss
--ability lines still come from the plan
function ns:BuildFightPlan(specKey, planText, readNotes, encounterId)
    ns.plan = {}
    ns.steps = {}
    ns.abilityAnchors = {}
    local unknown = {}
    local function StepsFor(entry)
        if ns.steps[entry] == nil then
            ns.steps[entry] = ns:GetEntrySteps(specKey, entry) or false
            if not ns.steps[entry] then
                table.insert(unknown, entry)
            end
        end
        return ns.steps[entry]
    end

    local plan = ns:ParsePlan(planText)
    local noteText = readNotes and ReadMrtNotes(specKey)
    local times = noteText and ns:ParsePlan(noteText).times or plan.times
    for _, timing in ipairs(times) do
        for _, step in ipairs(StepsFor(timing.entry) or {}) do
            local at = math.floor(timing.seconds - step.offset + 0.5)
            if at >= 0 and ns:ShouldUseStep(step) then
                ns.plan[timing.phase] = ns.plan[timing.phase] or {}
                table.insert(ns.plan[timing.phase], ns:CreateReminder(step, at))
            end
        end
    end
    for _, anchor in ipairs(plan.abilities) do
        if StepsFor(anchor.entry) then
            ns:ResolveAnchor(anchor, encounterId)
            table.insert(ns.abilityAnchors, anchor)
        end
    end
    if #unknown > 0 then
        ns:WriteOutput("Skipping what isn't a ramp or a spell you know: " .. table.concat(unknown, ', '))
    end
end

--Replaces the times of a boss plan with the player's lines of an MRT note. Boss ability lines and comments are kept
function ns:ImportNoteIntoPlan(specKey, diffSlug, encounterId, noteText)
    local parts = {}
    for _, text in ipairs({ ns:NoteToPlan(noteText, specKey), ns:KeepAbilityLines(ns:GetPlan(specKey, diffSlug, encounterId)) }) do
        if text ~= '' then
            table.insert(parts, text)
        end
    end
    ns:SetPlan(specKey, diffSlug, encounterId, table.concat(parts, '\n'))
end
