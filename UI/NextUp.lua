local _, ns = ...

--The Next up strip: the next few presses of the fight with how long until each, so a cooldown can be seen coming before
--its reminder shows. Moved in unlock mode like the reminders

local theme = ns.theme
local WIDTH = 230
local ROW_H = 22
local WINDOW = 60
local MAX_ROWS = 5

local strip

local function Options()
    return ns.db.options
end

function ns:NextUpSize()
    return WIDTH, ROW_H * Options().nextUpCount
end

local function CreateStrip()
    strip = CreateFrame("Frame", "CrescendoNextUp", UIParent)
    strip:SetFrameStrata("HIGH")
    strip.rows = {}
    for index = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, strip)
        row:SetHeight(ROW_H - 2)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_H)
        row.background = ns:Fill(row, { theme.window[1], theme.window[2], theme.window[3], 0.75 })
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetWidth(2)
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.time = ns:Text(row, 12, theme.text, "RIGHT")
        row.time:SetPoint("RIGHT", -6, 0)
        row.label = ns:Text(row, 12)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.label:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
        strip.rows[index] = row
    end
    ns:ResetNextUp()
end

--Puts the strip where the options say
function ns:ResetNextUp()
    if not strip then
        return
    end
    local options = Options()
    strip:ClearAllPoints()
    strip:SetPoint("CENTER", UIParent, "CENTER", options.nextUpX, options.nextUpY)
    strip:SetSize(ns:NextUpSize())
end

local PREVIEW = {
    { entry = "Power Word: Barrier", spell = 62618, timeLeft = 4.2 },
    { entry = "Evangelism", spell = 472433, timeLeft = 23 },
    { entry = "Pain Suppression", spell = 33206, timeLeft = 41, onCooldown = true }
}

--What the strip shows: the next presses of the fight, or examples while the reminders are previewed
local function Items()
    local options = Options()
    if options.toggleDisplay and options.nextUp then
        local items = {}
        for _, example in ipairs(PREVIEW) do
            local info = C_Spell.GetSpellInfo(example.spell)
            table.insert(items, { text = example.entry, icon = info and info.iconID, timeLeft = example.timeLeft, onCooldown = example.onCooldown })
        end
        return items
    end
    if not options.nextUp or not ns.fight.running then
        return {}
    end
    local items = {}
    for _, upcoming in ipairs(ns:GetUpcoming(options.nextUpCount, WINDOW)) do
        local reminder = upcoming.reminder
        table.insert(items, {
            text = reminder.entry or reminder.text,
            icon = reminder.icon,
            timeLeft = upcoming.timeLeft,
            onCooldown = ns:IsOnCooldownForReminder(reminder, upcoming.timeLeft)
        })
    end
    return items
end

--Seconds left like a cooldown shows them: 4.2 under ten seconds, then whole seconds rounded up, then 1:05
local function FormatLeft(seconds)
    seconds = math.max(0, seconds)
    if seconds < 10 then
        return string.format("%.1f", seconds)
    end
    local whole = math.ceil(seconds - 0.05)
    if whole < 60 then
        return tostring(whole)
    end
    return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

function ns:RefreshNextUp()
    local items = Items()
    if #items == 0 and not strip then
        return
    end
    if not strip then
        CreateStrip()
    end
    local r, g, b = ns:GetAccent()
    for index, row in ipairs(strip.rows) do
        local item = items[index]
        if item and index <= Options().nextUpCount then
            row.icon:SetTexture(item.icon or 134400)
            row.label:SetText(item.text .. (item.onCooldown and "  |cff8a8a8a(on cooldown)|r" or ""))
            row.time:SetText(FormatLeft(item.timeLeft))
            local soon = item.timeLeft <= 5
            row.bar:SetColorTexture(r, g, b, soon and 1 or 0.5)
            row.time:SetTextColor(soon and r or 1, soon and g or 1, soon and b or 1, 1)
            row:SetAlpha(item.onCooldown and 0.5 or 1)
            row:Show()
        else
            row:Hide()
        end
    end
    strip:SetShown(#items > 0)
end

--For tests
function ns:GetNextUpWidgets()
    return strip
end

--Kept up to date ten times a second while a fight runs or the reminders are previewed
local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then
        return
    end
    elapsed = 0
    if ns.db and (ns.fight.running or (strip and strip:IsShown()) or ns.db.options.toggleDisplay) then
        ns:RefreshNextUp()
    end
end)
