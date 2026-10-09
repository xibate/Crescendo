local _, ns = ...

--Whether the spell or trinket of a reminder is ready, for the option to leave out reminders of what is on cooldown.
--Cooldowns can be secret during encounters. Then the time is worked out from the player's last cast and the cooldown
--seen when it could be read, and when that isn't known either the reminder shows

local GCD_LIMIT = 2
local GRACE = 1

--GetTime() of the player's last cast of each spell
local lastCast = {}

local function Readable(...)
    for index = 1, select('#', ...) do
        local value = select(index, ...)
        if value == nil or ns:IsSecret(value) then
            return false
        end
    end
    return true
end

local function Learn(spellId, duration)
    if spellId and duration > GCD_LIMIT then
        ns.db.cooldowns[spellId] = duration
    end
end

local function Estimate(spellId)
    local duration = spellId and ns.db.cooldowns[spellId]
    if lastCast[spellId] and duration then
        return math.max(0, lastCast[spellId] + duration - GetTime())
    end
end

--Seconds until the spell or trinket of a reminder can be used, 0 when it is ready, nil when that can't be told.
--ref is { spellId } for a spell, or { slot or itemId, spellId of the use effect } for a trinket
function ns:CooldownLeft(ref)
    local now = GetTime()
    if ref.slot or ref.itemId then
        local start, duration
        if ref.slot then
            start, duration = GetInventoryItemCooldown("player", ref.slot)
        else
            start, duration = C_Item.GetItemCooldown(ref.itemId)
        end
        if Readable(start, duration) then
            if duration > GCD_LIMIT then
                Learn(ref.spellId, duration)
                return math.max(0, start + duration - now)
            end
            return 0
        end
        return Estimate(ref.spellId)
    end
    local spellId = ref.spellId
    local charges = C_Spell.GetSpellCharges(spellId)
    if charges then
        if Readable(charges.currentCharges, charges.maxCharges, charges.cooldownStartTime, charges.cooldownDuration) and charges.maxCharges > 1 then
            if charges.currentCharges > 0 then
                return 0
            end
            return math.max(0, charges.cooldownStartTime + charges.cooldownDuration - now)
        end
        --A spell with charges can have one left after a cast, the last cast doesn't tell
        if (ns.maxCharges[spellId] or 1) > 1 then
            return nil
        end
    end
    local cooldown = C_Spell.GetSpellCooldown(spellId)
    if cooldown and Readable(cooldown.startTime, cooldown.duration) then
        if cooldown.duration > GCD_LIMIT then
            Learn(spellId, cooldown.duration)
            return math.max(0, cooldown.startTime + cooldown.duration - now)
        end
        return 0
    end
    return Estimate(spellId)
end

--True when the option to leave out reminders of what is on cooldown is on, and the reminder's spell or trinket won't be
--ready by the time it should land. timeLeft is how long until the reminder's own time
function ns:IsOnCooldownForReminder(reminder, timeLeft)
    if not ns.db.options.hideOnCooldown or not reminder.cooldown then
        return false
    end
    local left = ns:CooldownLeft(reminder.cooldown)
    return left ~= nil and left > math.max(0, timeLeft) + (reminder.offset or 0) + GRACE
end

--Shows a reminder that is due, unless it is left out because its spell or trinket is on cooldown
function ns:Remind(reminder, timeLeft)
    reminder.shown = true
    if not ns:IsOnCooldownForReminder(reminder, timeLeft) then
        ns:ShowReminder(reminder)
    end
end

local casts = CreateFrame("Frame")
casts:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
casts:SetScript("OnEvent", function(_, _, _, _, spellId)
    if spellId == nil or ns:IsSecret(spellId) then
        return
    end
    lastCast[spellId] = GetTime()
    --Right after the cast the cooldown can often still be read, which tells how long it is with the player's talents
    C_Timer.NewTimer(0.2, function()
        if ns.db then
            local cooldown = C_Spell.GetSpellCooldown(spellId)
            if cooldown and Readable(cooldown.startTime, cooldown.duration) then
                Learn(spellId, cooldown.duration)
            end
        end
    end)
end)
