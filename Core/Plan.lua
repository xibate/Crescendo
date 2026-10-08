local _, ns = ...

--Reminders of the current fight: ns.plan[phase key] lists the reminders timed from the pull ('main') or from the start of
--a phase, as { at = seconds, text, icon, ..., shown }. ns.steps has the steps of everything turned on, by ramp or spell name
ns.plan = {}
ns.steps = {}

--In prerequisites only mode the final press of a ramp is left out
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

--Timings texts from the MRT notes the options say to read, by ramp or spell name, nil when no note is read
local function ReadMrtNotes(specName)
    local options = ns.db.options
    if not options.readFromNote and not options.mrtPersonalNote then
        return nil
    end
    local note = _G.VMRT and _G.VMRT.Note
    if not note then
        ns:WriteOutput("Reading timings from MRT notes is turned on, but MRT isn't loaded.")
        return nil
    end
    local texts = {}
    if options.readFromNote then
        table.insert(texts, note.Text1 or '')
    end
    if options.mrtPersonalNote then
        table.insert(texts, note.SelfText or '')
    end
    return ns:ParseNote(table.concat(texts, '\n'), specName)
end

--Builds the reminders for a fight from the timings texts saved for the boss, or the times in the MRT notes when the
--options say so. The '@ability' lines always come from the saved timings, see BossMods.lua
function ns:BuildFightPlan(specName, savedTimings, readNotes)
    ns.plan = {}
    ns.abilityAnchors = {}
    ns.steps = ns:GetSteps(specName)
    local noteTimings = readNotes and ReadMrtNotes(specName)
    for name, steps in pairs(ns.steps) do
        for _, anchor in ipairs(ns:ParseAbilityAnchors(savedTimings[name])) do
            anchor.entry = name
            table.insert(ns.abilityAnchors, anchor)
        end
        local text = savedTimings[name]
        if noteTimings then
            text = noteTimings[name]
        end
        for phase, times in pairs(ns:ParseTimes(text)) do
            ns.plan[phase] = ns.plan[phase] or {}
            for _, seconds in ipairs(times) do
                for _, step in ipairs(steps) do
                    local at = math.floor(seconds - step.offset + 0.5)
                    if at >= 0 and ns:ShouldUseStep(step) then
                        table.insert(ns.plan[phase], ns:CreateReminder(step, at))
                    end
                end
            end
        end
    end
end

--Replaces the times saved for a boss with the player's lines of the note pasted in the import box. '@ability' lines are kept
function ns:ImportNote(specName)
    local import = ns.db.import
    if not import.fight or not import.difficulty or not import.importText then
        return
    end
    local difficulty = ns.difficulties[import.difficulty]
    local timings = ns:GetBossTimings(specName, difficulty.slug, import.fight)
    local imported = ns:ParseNote(import.importText, specName)
    for name, text in pairs(timings) do
        timings[name] = ns:KeepAbilityLines(text)
    end
    for name, text in pairs(imported) do
        timings[name] = (timings[name] or '') .. text
    end
    import.importText = ''
    ns:WriteOutput('Imported ' .. specName .. ' timings for ' .. difficulty.name .. ' ' .. ns.bosses[import.fight].name)
end

--Puts the times saved for the boss selected in the import box in the box as MRT note lines
function ns:ExportNote(specName)
    local import = ns.db.import
    if import.fight and import.difficulty then
        local timings = ns:GetBossTimings(specName, ns.difficulties[import.difficulty].slug, import.fight)
        import.importText = ns:BuildNote(specName, timings)
    end
end
