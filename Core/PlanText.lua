local _, ns = ...

--A plan has one line per timing, each naming one or more ramps or spells:
--  01:25 - Evangelism                  1 minute 25 after the pull
--  00:50 p2 - Ultimate Penitence       50 seconds after the boss mod shows stage 2, intermissions are stages like p1.5
--  @Spectral Coils #2 -3 - Barrier     3 seconds before the 2nd Spectral Coils on the boss mod bar, see Core/BossMods.lua
--  02:10 - Rewind, Time Dilation       several at the same time, a spell id works instead of a name
--The dash can be left out after a time. Lines starting with -- are comments

local function Trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function SplitEntries(text)
    local entries = {}
    for entry in text:gmatch('[^,]+') do
        entry = Trim(entry)
        if entry ~= '' then
            table.insert(entries, entry)
        end
    end
    return entries
end

--'Spectral Coils #2,4 -3' into the ability, the casts it applies to and the shift in seconds
local function ParseAbility(text)
    local anchor = { shift = 0 }
    local shift = text:match('%s([%+%-]%d+%.?%d*)$')
    if shift then
        anchor.shift = tonumber(shift)
        text = text:gsub('%s[%+%-]%d+%.?%d*$', '')
    end
    local counts = text:match('#%s*([%d%s,]+)$')
    if counts then
        anchor.counts = {}
        for count in counts:gmatch('%d+') do
            anchor.counts[tonumber(count)] = true
        end
        text = text:gsub('%s*#%s*[%d%s,]+$', '')
    end
    text = Trim(text)
    anchor.spellId = tonumber(text)
    anchor.name = text:lower()
    return anchor
end

--One plan line. Returns 'time' or 'ability' with the parsed line, 'skip' for blank and comment lines, or nil and what is wrong
local function ParseLine(line)
    if line:find('^%s*$') or line:find('^%s*%-%-') then
        return 'skip'
    end
    local ability = line:match('^%s*@(.*)$')
    if ability then
        local trigger, entries = ability:match('^(.*)%s%-%s(.-)$')
        if not trigger or Trim(trigger) == '' or Trim(entries) == '' then
            return nil, "'" .. line .. "' needs a dash before the ramp or spell, like @Spectral Coils #2 - Evangelism"
        end
        local anchor = ParseAbility(Trim(trigger))
        anchor.entries = SplitEntries(entries)
        return 'ability', anchor
    end
    local minutes, seconds, rest = line:match('^%s*(%d+):(%d+%.?%d*)(.*)$')
    if minutes then
        seconds = tonumber(minutes) * 60 + tonumber(seconds)
    else
        seconds, rest = line:match('^%s*(%d+%.?%d*)(.*)$')
        seconds = tonumber(seconds)
    end
    if not seconds then
        return nil, "'" .. line .. "' doesn't start with a time like 01:25 or a boss ability like @Spectral Coils"
    end
    local timing = { seconds = seconds, phase = 'main' }
    local phase, afterPhase = rest:match('^,?%s*p%s*(%d+%.?%d*)(.*)$')
    if phase then
        timing.phase = ns:PhaseKey(phase)
        rest = afterPhase
    end
    timing.entries = SplitEntries(rest:match('^%s*%-?%s*(.-)%s*$'))
    if #timing.entries == 0 then
        return nil, "'" .. line .. "' doesn't say which ramp or spell, like 01:25 - Evangelism"
    end
    return 'time', timing
end

--Reads a plan into its timed entries { seconds, phase, entry } and ability lines { name, spellId, counts, shift, entry }
function ns:ParsePlan(text)
    local plan = { times = {}, abilities = {} }
    for line in ns:Lines(text) do
        local kind, parsed = ParseLine(line)
        if kind == 'time' then
            for _, entry in ipairs(parsed.entries) do
                table.insert(plan.times, { seconds = parsed.seconds, phase = parsed.phase, entry = entry })
            end
        elseif kind == 'ability' then
            for _, entry in ipairs(parsed.entries) do
                table.insert(plan.abilities, { name = parsed.name, spellId = parsed.spellId, counts = parsed.counts, shift = parsed.shift, entry = entry })
            end
        end
    end
    return plan
end

--True when every line of a plan can be read, otherwise what is wrong with the first line that can't
function ns:CheckPlan(text)
    for line in ns:Lines(text) do
        local kind, problem = ParseLine(line)
        if not kind then
            return problem
        end
    end
    return true
end

--Boss abilities, as listed in Config/Abilities.lua, are { spellId, name }. An ability line names one by its name, or by
--its spell id when the boss has two abilities with that name
function ns:AbilityLineText(encounterId, ability)
    if not ability.name then
        return tostring(ability.spellId)
    end
    local sameName = 0
    for _, other in ipairs(ns.bossAbilities[encounterId] or {}) do
        if other.name:lower() == ability.name:lower() then
            sameName = sameName + 1
        end
    end
    if sameName > 1 and ability.spellId then
        return tostring(ability.spellId)
    end
    return ability.name
end

local function LineMatchesAbility(anchor, ability)
    if anchor.spellId then
        return anchor.spellId == ability.spellId
    end
    return ability.name ~= nil and anchor.name == ability.name:lower()
end

local function SortedCasts(counts)
    if not counts then
        return nil
    end
    local casts = {}
    for count in pairs(counts) do
        table.insert(casts, count)
    end
    table.sort(casts)
    return casts
end

local function FormatSeconds(seconds)
    if seconds == math.floor(seconds) then
        return tostring(seconds)
    end
    return string.format('%.1f', seconds)
end

--The assignments to one boss ability in a plan, one per ramp or spell in plan order:
--{ casts = { 2, 4 } or nil for every cast, before = seconds before the ability the ramp lands, entry = ramp or spell }
function ns:GetAbilityAssignments(planText, ability)
    local assignments = {}
    for line in ns:Lines(planText) do
        local kind, parsed = ParseLine(line)
        if kind == 'ability' and LineMatchesAbility(parsed, ability) then
            for _, entry in ipairs(parsed.entries) do
                table.insert(assignments, { casts = SortedCasts(parsed.counts), before = parsed.shift == 0 and 0 or -parsed.shift, entry = entry })
            end
        end
    end
    return assignments
end

--An assignment as an ability line, like '@Spectral Coils #2,4 -3 - Evangelism'
function ns:FormatAbilityLine(abilityText, assignment)
    local line = '@' .. abilityText
    if assignment.casts and #assignment.casts > 0 then
        line = line .. ' #' .. table.concat(assignment.casts, ',')
    end
    local before = assignment.before or 0
    if before > 0 then
        line = line .. ' -' .. FormatSeconds(before)
    elseif before < 0 then
        line = line .. ' +' .. FormatSeconds(-before)
    end
    return line .. ' - ' .. Trim(assignment.entry)
end

--Replaces the assignments to one boss ability in a plan. Every other line stays where it is, the new ability lines go
--where the first old one was, or at the end. Assignments without a ramp or spell are left out
function ns:SetAbilityAssignments(planText, encounterId, ability, assignments)
    local lines, insertAt = {}, nil
    for line in ((planText or '') .. '\n'):gmatch('(.-)\r?\n') do
        local kind, parsed = ParseLine(line)
        if kind == 'ability' and LineMatchesAbility(parsed, ability) then
            insertAt = insertAt or #lines + 1
        else
            table.insert(lines, line)
        end
    end
    while #lines > 0 and lines[#lines]:find('^%s*$') do
        table.remove(lines)
    end
    insertAt = math.min(insertAt or #lines + 1, #lines + 1)
    local abilityText = ns:AbilityLineText(encounterId, ability)
    for _, assignment in ipairs(assignments) do
        if assignment.entry and assignment.entry:find('%S') then
            table.insert(lines, insertAt, ns:FormatAbilityLine(abilityText, assignment))
            insertAt = insertAt + 1
        end
    end
    return table.concat(lines, '\n')
end

--Only the boss ability lines and comments of a plan, kept when times are imported from a note
function ns:KeepAbilityLines(text)
    local kept = {}
    for line in ns:Lines(text) do
        if line:find('^%s*@') or line:find('^%s*%-%-') then
            table.insert(kept, line)
        end
    end
    return table.concat(kept, '\n')
end

--Name of the ramp or spell an MRT note means by a spell id
local function EntryForSpell(specKey, spellId)
    for name, ramp in pairs(ns:GetRamps(specKey)) do
        if ramp.spellId == spellId then
            return name
        end
    end
    local trinket = ns:TrinketEntryForSpell(spellId)
    if trinket then
        return trinket
    end
    local info = C_Spell.GetSpellInfo(spellId)
    return info and info.name
end

--MRT note times are '01:30' or '01:30,p2'. Phases marked with combat log events can't be followed anymore
local function ReadNoteTime(noteTime)
    local time, phase = nil, nil
    for part in noteTime:gmatch('[^,]+') do
        local phaseNumber = part:match('^%s*p(%d+%.?%d*)%s*$')
        if phaseNumber then
            phase = ns:PhaseKey(phaseNumber)
        elseif time then
            return nil
        else
            time = Trim(part)
        end
    end
    if not time or not (time:find('^%d+:%d+%.?%d*$') or time:find('^%d+%.?%d*$')) then
        return nil
    end
    if not phase and noteTime:find(',') then
        return nil
    end
    return time .. (phase and (' p' .. phase) or '')
end

--The player's lines of an MRT note as plan lines. A note line looks like '{time:01:30,p2} - Playername {spell:472433}'
function ns:NoteToPlan(noteText, specKey)
    local playerName = UnitName("player")
    local spellPattern = playerName:gsub('%p', '%%%0') .. ' {spell:(%d+)}'
    local lines = {}
    for line in ns:Lines(noteText) do
        local noteTime = line:match('{time:([^}]+)}')
        if noteTime and line:find(playerName, 1, true) and line:find('{spell:', 1, true) then
            local time = ReadNoteTime(noteTime)
            if time then
                for spellId in line:gmatch(spellPattern) do
                    local entry = EntryForSpell(specKey, tonumber(spellId))
                    if entry then
                        table.insert(lines, time .. ' - ' .. entry)
                    end
                end
            else
                ns:WriteOutput("The note line |cffffd100" .. line .. "|r uses a time or phase this addon can't follow, it is skipped.")
            end
        end
    end
    return table.concat(lines, '\n')
end

--The timed lines of a plan as MRT note lines for the player, ordered by phase and time. Ability lines have no note form
function ns:PlanToNote(planText, specKey)
    local playerName = UnitName("player")
    local entries = {}
    for _, timing in ipairs(ns:ParsePlan(planText).times) do
        local ramp = ns:FindRamp(specKey, timing.entry)
        local trinket = not ramp and ns:FindTrinket(timing.entry)
        local info = not ramp and not trinket and C_Spell.GetSpellInfo(tonumber(timing.entry) or timing.entry)
        local spellId = ramp and ramp.spellId or trinket and trinket.spellId or info and info.spellID
        if spellId then
            local phase = timing.phase ~= 'main' and (',p' .. timing.phase) or ''
            table.insert(entries, {
                phase = timing.phase == 'main' and 0 or tonumber(timing.phase),
                seconds = timing.seconds,
                line = "{time:" .. ns:FormatTime(timing.seconds) .. phase .. "} - " .. playerName .. " {spell:" .. spellId .. "}"
            })
        end
    end
    table.sort(entries, function(a, b)
        if a.phase ~= b.phase then
            return a.phase < b.phase
        end
        if a.seconds ~= b.seconds then
            return a.seconds < b.seconds
        end
        return a.line < b.line
    end)
    local lines = {}
    for _, entry in ipairs(entries) do
        table.insert(lines, entry.line)
    end
    return table.concat(lines, '\n')
end
