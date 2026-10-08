local _, ns = ...

--A timings box has one entry per line:
--  01:25 or 85          seconds after the pull
--  00:50, p2            seconds after the boss mod switches to stage 2 (p1.5 for an intermission)
--  @Spectral Coils #2   a boss ability, see ParseAbilityAnchors

local function IsAbilityLine(line)
    return line:find('^%s*@') ~= nil
end

local function IsBlank(line)
    return line:find('^%s*$') ~= nil
end

local function ParseSeconds(text)
    local minutes, seconds = text:match('^%s*(%d+):(%d+%.?%d*)%s*$')
    if minutes then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end
    return tonumber(text)
end

--Reads one time line into its seconds and phase key ('main' without a phase), nil when it isn't a valid time
local function ParseTimeLine(line)
    local seconds, phase = nil, 'main'
    for part in line:gmatch('[^,]+') do
        local phaseNumber = part:match('^%s*p%s*(%d+%.?%d*)%s*$')
        if phaseNumber then
            phase = ns:PhaseKey(phaseNumber)
        else
            seconds = ParseSeconds(part)
        end
    end
    if seconds then
        return seconds, phase
    end
end

--The time lines of a timings box by phase key, { main = { 85 }, ['2'] = { 50 } }
function ns:ParseTimes(text)
    local times = { main = {} }
    for line in ns:Lines(text) do
        if not IsAbilityLine(line) then
            local seconds, phase = ParseTimeLine(line)
            if seconds then
                times[phase] = times[phase] or {}
                table.insert(times[phase], seconds)
            end
        end
    end
    return times
end

--Reads the boss ability lines of a timings box. '@Spectral Coils' is every cast, '@Spectral Coils #2,4' only the
--2nd and 4th cast as counted on the boss mod bar, a spell id works instead of the name and '-2' or '+1' at the end
--moves the ramp that many seconds before or after the ability
function ns:ParseAbilityAnchors(text)
    local anchors = {}
    for line in ns:Lines(text) do
        local ability = line:match('^%s*@%s*(.-)%s*$')
        if ability and ability ~= '' then
            local anchor = { shift = 0 }
            local shift = ability:match('%s([%+%-]%d+%.?%d*)$')
            if shift then
                anchor.shift = tonumber(shift)
                ability = ability:gsub('%s[%+%-]%d+%.?%d*$', '')
            end
            local counts = ability:match('#%s*([%d%s,]+)$')
            if counts then
                anchor.counts = {}
                for count in counts:gmatch('%d+') do
                    anchor.counts[tonumber(count)] = true
                end
                ability = ability:gsub('%s*#%s*[%d%s,]+$', '')
            end
            anchor.spellId = tonumber(ability)
            anchor.name = ability:lower()
            table.insert(anchors, anchor)
        end
    end
    return anchors
end

--Only the boss ability lines of a timings box, so importing a note doesn't remove them
function ns:KeepAbilityLines(text)
    local kept = ''
    for line in ns:Lines(text) do
        if IsAbilityLine(line) then
            kept = kept .. line .. '\n'
        end
    end
    return kept
end

--Every line of a timings box has to be a time, a phase time or a boss ability
function ns:IsValidTimingsText(text)
    for line in ns:Lines(text) do
        if not IsAbilityLine(line) and not IsBlank(line) and not ParseTimeLine(line) then
            return false
        end
    end
    return true
end

--MRT note times are '01:30' or '01:30,p2'. Notes made for older addons can mark phases with combat log events,
--those can't be followed anymore
local function NoteTimeToTiming(noteTime)
    local timing, phase = nil, nil
    for part in noteTime:gmatch('[^,]+') do
        local phaseNumber = part:match('^%s*p(%d+%.?%d*)%s*$')
        if phaseNumber then
            phase = ns:PhaseKey(phaseNumber)
        elseif timing then
            return nil
        else
            timing = part
        end
    end
    if not timing or not ParseSeconds(timing) then
        return nil
    end
    if phase then
        return timing .. ', p' .. phase
    end
    if not noteTime:find(',') then
        return timing
    end
end

--The player's lines of an MRT note as timings texts by ramp or spell name. A line looks like
--'{time:01:30,p2} - Playername {spell:472433}'
function ns:ParseNote(noteText, specName)
    local playerName = UnitName("player")
    local spellPattern = playerName:gsub('%p', '%%%0') .. ' {spell:(%d+)}'
    local spellList = ns:GetSpellList(specName)
    local timings = {}
    for line in ns:Lines(noteText) do
        local noteTime = line:match('{time:([^}]+)}')
        if noteTime and line:find(playerName, 1, true) and line:find('{spell:', 1, true) then
            local timing = NoteTimeToTiming(noteTime)
            if timing then
                for spellId in line:gmatch(spellPattern) do
                    local name = spellList[tonumber(spellId)]
                    if name then
                        timings[name] = (timings[name] or '') .. timing .. '\n'
                    end
                end
            else
                ns:WriteOutput("The line |cffffd100" .. line .. "|r isn't properly formatted or uses a phase this addon can't follow, it is being ignored.")
            end
        end
    end
    return timings
end

--Writes timings texts by ramp or spell name as MRT note lines for the player, ordered by phase and time
function ns:BuildNote(specName, timingsByName)
    local playerName = UnitName("player")
    local spellIds = {}
    for spellId, name in pairs(ns:GetSpellList(specName)) do
        if not spellIds[name] or spellId < spellIds[name] then
            spellIds[name] = spellId
        end
    end
    local entries = {}
    for name, text in pairs(timingsByName) do
        if spellIds[name] then
            for phase, times in pairs(ns:ParseTimes(text)) do
                for _, seconds in ipairs(times) do
                    table.insert(entries, {
                        phase = phase == 'main' and 0 or tonumber(phase),
                        seconds = seconds,
                        line = "{time:" .. ns:FormatTime(seconds) .. (phase == 'main' and '' or ',p' .. phase) .. "} - " .. playerName .. " {spell:" .. spellIds[name] .. "}"
                    })
                end
            end
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
    local note = ''
    for _, entry in ipairs(entries) do
        note = note .. entry.line .. "\n"
    end
    return note
end
