local _, ns = ...

--Plans to share with other players, as text that can be pasted anywhere:
--  ##crescendo 1
--  ##spec Discipline
--  ##plan 3492 myth Ula'tek          a plan, its lines follow
--  ##ramp 472433 Evangelism          a ramp the plans use, its steps follow (0 when it has no spell id)
--  ##end
--Importing replaces the plans for those bosses, and adds the ramps the player doesn't have yet

local HEADER = '##crescendo 1'

local function Trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function TextLines(text)
    local lines = {}
    for line in ((text or '') .. '\n'):gmatch('(.-)\r?\n') do
        table.insert(lines, line)
    end
    return lines
end

--A share string of a spec's plans, { encounterId, diffSlug } each, with the ramps they use. Nil when the plans are empty
function ns:ExportPlans(specKey, plans)
    local lines = { HEADER, '##spec ' .. specKey }
    local ramps, rampOrder, count = {}, {}, 0
    for _, which in ipairs(plans) do
        local text = ns:GetPlan(specKey, which.diffSlug, which.encounterId)
        if text:find('%S') then
            count = count + 1
            local boss = ns.bosses[which.encounterId]
            table.insert(lines, '##plan ' .. which.encounterId .. ' ' .. which.diffSlug .. (boss and (' ' .. boss.name) or ''))
            for _, line in ipairs(TextLines(text)) do
                if line:find('%S') then
                    table.insert(lines, line)
                end
            end
            local parsed = ns:ParsePlan(text)
            for _, list in ipairs({ parsed.times, parsed.abilities }) do
                for _, timing in ipairs(list) do
                    local ramp, name = ns:FindRamp(specKey, timing.entry)
                    if ramp and not ramps[name] then
                        ramps[name] = ramp
                        table.insert(rampOrder, name)
                    end
                end
            end
        end
    end
    if count == 0 then
        return nil, 0
    end
    table.sort(rampOrder)
    for _, name in ipairs(rampOrder) do
        table.insert(lines, '##ramp ' .. (ramps[name].spellId or 0) .. ' ' .. name)
        for _, line in ipairs(TextLines(ramps[name].steps)) do
            if line:find('%S') then
                table.insert(lines, line)
            end
        end
    end
    table.insert(lines, '##end')
    return table.concat(lines, '\n'), count
end

--Reads a share string into { specKey, plans = { encounterId, diffSlug, text }, ramps = { name, spellId, steps } }, or nil
--and what is wrong with it
function ns:ReadPlanString(text)
    local data = { plans = {}, ramps = {} }
    local current, started
    local function Finish()
        if current then
            current.body = table.concat(current.lines, '\n')
            current.lines = nil
        end
        current = nil
    end
    for _, raw in ipairs(TextLines(text)) do
        local line = raw:gsub('%s+$', '')
        local command, rest = line:match('^%s*##(%a+)%s*(.-)$')
        if command then
            command = command:lower()
            if command == 'crescendo' then
                started = true
            elseif not started then
                return nil, "This isn't a Crescendo plan string, it starts with ##crescendo"
            elseif command == 'spec' then
                data.specKey = Trim(rest)
            elseif command == 'plan' then
                Finish()
                local encounterId, diffSlug = rest:match('^(%d+)%s+(%a+)')
                if not encounterId then
                    return nil, "'" .. line .. "' doesn't say which boss and difficulty"
                end
                current = { encounterId = tonumber(encounterId), diffSlug = diffSlug, lines = {} }
                table.insert(data.plans, current)
            elseif command == 'ramp' then
                Finish()
                local spellId, name = rest:match('^(%d+)%s+(.+)$')
                if not name then
                    return nil, "'" .. line .. "' doesn't name the ramp"
                end
                current = { name = Trim(name), spellId = tonumber(spellId) ~= 0 and tonumber(spellId) or nil, lines = {} }
                table.insert(data.ramps, current)
            elseif command == 'end' then
                Finish()
                break
            end
        elseif current and line:find('%S') then
            table.insert(current.lines, Trim(line))
        end
    end
    Finish()
    if not started then
        return nil, "Paste a Crescendo plan string, it starts with ##crescendo"
    end
    if not ns.specNames[data.specKey or ''] then
        return nil, "The string is for a spec this addon doesn't know: " .. tostring(data.specKey)
    end
    if #data.plans == 0 then
        return nil, "The string has no plans in it"
    end
    for _, plan in ipairs(data.plans) do
        local isDifficulty = false
        for _, difficulty in pairs(ns.difficulties) do
            isDifficulty = isDifficulty or difficulty.slug == plan.diffSlug
        end
        if not ns.bosses[plan.encounterId] or not isDifficulty then
            return nil, "The string has a plan for a boss or difficulty this version doesn't have (" .. plan.encounterId .. " " .. plan.diffSlug .. ")"
        end
        local check = ns:CheckPlan(plan.body)
        if check ~= true then
            return nil, ns.bosses[plan.encounterId].name .. ": " .. check
        end
        plan.text = plan.body
    end
    for _, ramp in ipairs(data.ramps) do
        local steps, problem = ns:ParseRampSteps(ramp.body)
        if not steps then
            return nil, ramp.name .. ": " .. problem
        end
        ramp.steps = ramp.body
    end
    return data
end

local function DifficultyName(diffSlug)
    for _, difficulty in pairs(ns.difficulties) do
        if difficulty.slug == diffSlug then
            return difficulty.name
        end
    end
    return diffSlug
end

--What importing a read share string does, in words
function ns:DescribePlanImport(data)
    local plans = {}
    for _, plan in ipairs(data.plans) do
        local replaces = ns:GetPlan(data.specKey, plan.diffSlug, plan.encounterId):find('%S') and ", replaces yours" or ""
        table.insert(plans, ns.bosses[plan.encounterId].name .. " (" .. DifficultyName(plan.diffSlug) .. replaces .. ")")
    end
    local text = #data.plans .. (#data.plans == 1 and " plan" or " plans") .. " for " .. ns.specNames[data.specKey] .. ": " .. table.concat(plans, ", ")
    local added, kept = {}, {}
    for _, ramp in ipairs(data.ramps) do
        local own = ns:FindRamp(data.specKey, ramp.name)
        if not own then
            table.insert(added, ramp.name)
        elseif own.steps ~= ramp.steps then
            table.insert(kept, ramp.name)
        end
    end
    if #added > 0 then
        text = text .. ". Adds " .. table.concat(added, ", ")
    end
    if #kept > 0 then
        text = text .. ". Keeps your own " .. table.concat(kept, ", ")
    end
    return text
end

--Imports a read share string: its plans replace the plans for those bosses, and ramps the player doesn't have are added
function ns:ImportPlans(data)
    for _, plan in ipairs(data.plans) do
        ns:SetPlan(data.specKey, plan.diffSlug, plan.encounterId, plan.text)
    end
    for _, ramp in ipairs(data.ramps) do
        if not ns:FindRamp(data.specKey, ramp.name) then
            ns:GetRamps(data.specKey)[ramp.name] = { spellId = ramp.spellId, steps = ramp.steps }
        end
    end
end
