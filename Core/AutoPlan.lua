local _, ns = ...

--Auto-plan: spreads ramps, cooldowns and trinkets over the casts of a recorded pull that should be covered. Casts are
--gone through in time order and each gets the first of the chosen entries (in their order) that is ready by then,
--counting what the plan already uses and what was given out before, so nothing lands while it is on cooldown

--True when using entry at 'at' keeps every use ready in time: the plan's own, the ones given out so far and this one
local function FitsCooldowns(specKey, used, entry, at)
    local before, after = {}, {}
    for _, use in ipairs(used) do
        table.insert(before, { entry = use.entry, at = use.at })
        table.insert(after, { entry = use.entry, at = use.at })
    end
    table.insert(after, { entry = entry, at = at })
    return ns:FindCooldownConflicts(specKey, after) <= ns:FindCooldownConflicts(specKey, before)
end

--Picks what goes on which cast. casts are casts of a timeline (see Core/Timeline.lua) with a count, entries the ramps,
--spells and trinkets to use, best first, and before how many seconds before the cast they land. With skipAssigned,
--casts that have something assigned are left as they are. Returns the picks { cast, entry } and the casts nothing was
--ready for
function ns:AutoPlan(specKey, timeline, casts, entries, before, skipAssigned)
    local used = {}
    for _, use in ipairs(timeline.uses or {}) do
        table.insert(used, { entry = use.entry, at = use.at })
    end
    local sorted = {}
    for _, cast in ipairs(casts) do
        if cast.count and not (skipAssigned and cast.assigned) then
            table.insert(sorted, cast)
        end
    end
    table.sort(sorted, function(a, b) return a.at < b.at end)
    local picks, uncovered = {}, {}
    for _, cast in ipairs(sorted) do
        local at = math.max(0, cast.at - (before or 0))
        local chosen
        for _, entry in ipairs(entries) do
            if FitsCooldowns(specKey, used, entry, at) then
                chosen = entry
                break
            end
        end
        if chosen then
            table.insert(used, { entry = chosen, at = at })
            table.insert(picks, { cast = cast, entry = chosen })
        else
            table.insert(uncovered, cast)
        end
    end
    return picks, uncovered
end

--Writes picks into the plan as assignments for each cast, by ability and stage (or every stage for a boss without
--stages), after the assignments there already are. The plan before is kept in History. Returns how many casts got one
function ns:ApplyAutoPlan(specKey, diffSlug, encounterId, picks, before, byStage)
    local groups, order = {}, {}
    for _, pick in ipairs(picks) do
        local ability = pick.cast.lane.ability
        local scope = byStage and pick.cast.stage or 'all'
        local key = pick.cast.lane.key .. '|' .. scope
        local group = groups[key]
        if not group then
            group = { ability = ability, scope = scope, entries = {}, entryOrder = {} }
            groups[key] = group
            table.insert(order, key)
        end
        if not group.entries[pick.entry] then
            group.entries[pick.entry] = {}
            table.insert(group.entryOrder, pick.entry)
        end
        table.insert(group.entries[pick.entry], pick.cast.count)
    end
    if #order == 0 then
        return 0
    end
    ns:BackupPlan(specKey, diffSlug, encounterId, "Before auto-plan")
    local text = ns:GetPlan(specKey, diffSlug, encounterId)
    for _, key in ipairs(order) do
        local group = groups[key]
        local assignments = ns:GetAbilityAssignments(text, group.ability, group.scope)
        for _, entry in ipairs(group.entryOrder) do
            local castNumbers = group.entries[entry]
            table.sort(castNumbers)
            table.insert(assignments, { entry = entry, casts = castNumbers, before = before or 0 })
        end
        text = ns:SetAbilityAssignments(text, encounterId, group.ability, assignments, group.scope)
    end
    ns:SetPlan(specKey, diffSlug, encounterId, text)
    return #picks
end
