local _, ns = ...

--Plans sent to other Crescendo users in game: the group, or one player. A share string (see Core/Share.lua) goes in
--numbered parts as addon messages, '<id>:<part>:<parts>:<text>', paced so the game doesn't throttle them. A player who
--receives plans is asked before anything is imported (see UI/Received.lua)

local PREFIX = "Crescendo"
local PART_LENGTH = 220
local INTERVAL = 0.3
local STALE = 120
--What SendAddonMessage returns when it is sending too much: try again a moment later
local THROTTLED = { [3] = true, [8] = true }

local queue = {}
local sending = false
local sendId = 0
local incoming = {}
local listener

local function ShortName(name)
    if Ambiguate then
        return Ambiguate(name or '', "none")
    end
    return ((name or ''):gsub('%-.*$', ''))
end

--The channel to reach the whole group with, nil when not in one
function ns:GroupChannel()
    if IsInRaid and IsInRaid() then
        return "RAID"
    elseif IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

--Whether plans can be sent right now, and why not
function ns:CanSendPlans()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false, "Sending plans isn't available in this version of the game"
    end
    if ns.fight and ns.fight.running and not ns.fight.test then
        return false, "Plans can't be sent during a boss fight"
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false, "The game doesn't allow addon messages right now, try again after the fight"
    end
    return true
end

local function Progress(index, count, problem)
    if ns.OnSendProgress then
        ns:OnSendProgress(index, count, problem)
    end
end

local function Pump()
    local message = table.remove(queue, 1)
    if not message then
        sending = false
        return
    end
    local result = C_ChatInfo.SendAddonMessage(PREFIX, message.text, message.channel, message.target)
    if type(result) == 'number' and result ~= 0 then
        if THROTTLED[result] then
            table.insert(queue, 1, message)
            C_Timer.NewTimer(1, Pump)
            return
        end
        queue = {}
        sending = false
        Progress(message.index, message.count, result == 5 and "You're not in a group" or ("The game didn't send it (" .. result .. ")"))
        return
    end
    Progress(message.index, message.count)
    C_Timer.NewTimer(INTERVAL, Pump)
end

--Sends a share string to the group (target nil) or to a player. Returns how many parts it takes, or nil and why not
function ns:SendPlans(text, target)
    local ok, problem = ns:CanSendPlans()
    if not ok then
        return nil, problem
    end
    local channel = target and "WHISPER" or ns:GroupChannel()
    if not channel then
        return nil, "You're not in a group"
    end
    if not ns:ReadPlanString(text) then
        return nil, "There is nothing to send"
    end
    sendId = sendId % 9999 + 1
    local count = math.ceil(#text / PART_LENGTH)
    for index = 1, count do
        table.insert(queue, { channel = channel, target = target, index = index, count = count,
            text = sendId .. ':' .. index .. ':' .. count .. ':' .. text:sub((index - 1) * PART_LENGTH + 1, index * PART_LENGTH) })
    end
    if not sending then
        sending = true
        Pump()
    end
    return count
end

function ns:IsSendingPlans()
    return sending
end

--Collects the parts of plans someone sends; once all are in, the player is asked whether to import them
local function OnMessage(message, sender)
    if ShortName(sender) == UnitName("player") then
        return
    end
    local id, index, count, text = message:match('^(%d+):(%d+):(%d+):(.*)$')
    index, count = tonumber(index), tonumber(count)
    if not id or index < 1 or index > count or count > 2000 then
        return
    end
    local now = GetTime()
    for key, transfer in pairs(incoming) do
        if now - transfer.updated > STALE then
            incoming[key] = nil
        end
    end
    local key = sender .. ':' .. id
    local transfer = incoming[key]
    if not transfer or transfer.count ~= count then
        transfer = { count = count, parts = {}, received = 0 }
        incoming[key] = transfer
    end
    transfer.updated = now
    if not transfer.parts[index] then
        transfer.parts[index] = text
        transfer.received = transfer.received + 1
    end
    if transfer.received == count then
        incoming[key] = nil
        local data, problem = ns:ReadPlanString(table.concat(transfer.parts))
        if data then
            ns:AskToImport(ShortName(sender), data)
        else
            ns:WriteOutput(ShortName(sender) .. " sent plans that can't be read: " .. tostring(problem))
        end
    end
end

function ns:SetUpComms()
    if listener or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then
        return
    end
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    listener = CreateFrame("Frame")
    listener:RegisterEvent("CHAT_MSG_ADDON")
    listener:SetScript("OnEvent", function(_, _, prefix, message, _, sender)
        if prefix == PREFIX and not ns:IsSecret(message) and not ns:IsSecret(sender) and type(message) == 'string' and type(sender) == 'string' then
            OnMessage(message, sender)
        end
    end)
end
