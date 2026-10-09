local _, ns = ...

--Since Midnight some values are secret during encounters: addons can pass them along but can't do math or comparisons with them
function ns:IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

--Phases are stored under a string key: '2', '02' and 2 all become '2'. Boss mods use stages like 1.5 for intermissions
function ns:PhaseKey(phase)
    local number = tonumber(phase)
    if number then
        return tostring(number)
    end
    return tostring(phase)
end

--Seconds to mm:ss
function ns:FormatTime(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

--Iterates the lines of a text, skipping empty ones
function ns:Lines(text)
    return (text or ''):gmatch("[^\r\n]+")
end

--Prints a message in chat with the addon name in front
function ns:WriteOutput(text)
    print('|cff0cd29fCrescendo:|r ' .. text)
end
