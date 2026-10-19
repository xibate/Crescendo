local _, ns = ...

--Reminder displays, in the style of the addon's window: the spell icon in a thin border, the text on a dark strip below
--it, and a countdown on the icon with a bar that runs out while the reminder shows. Reminders with a countdown get an
--accent coloured border. Extra displays are added next to the first one, in the grow direction, when several reminders
--show at once
ns.frames = {}

local SHOW_SECONDS = 3
local FADE_IN = 0.12
local FADE_OUT = 0.35
local BAR_HEIGHT = 3

local GROW_POINTS = {
    top = { child = "BOTTOM", parent = "TOP", x = 0, y = 1 },
    bottom = { child = "TOP", parent = "BOTTOM", x = 0, y = -1 },
    left = { child = "RIGHT", parent = "LEFT", x = -1, y = 0 },
    right = { child = "LEFT", parent = "RIGHT", x = 1, y = 0 }
}

local function PlaceFrame(index)
    local options = ns.db.options
    local frame = ns.frames[index]
    frame:ClearAllPoints()
    if index == 1 then
        frame:SetPoint("CENTER", options.framePositionX, options.framePositionY)
    else
        local grow = GROW_POINTS[options.growDirection] or GROW_POINTS.top
        frame:SetPoint(grow.child, ns.frames[index - 1], grow.parent, grow.x * options.displaySpacing, grow.y * options.displaySpacing)
    end
end

local function StyleFrame(frame)
    local options = ns.db.options
    local font = ns:GetFont()
    frame.box:SetSize(options.iconSizeW + 2, options.iconSizeH + 2)
    frame.text:SetFont(font, 12, "OUTLINE")
    frame.text:SetScale(options.textSize)
    frame.timer:SetFont(font, 14, "OUTLINE")
    frame.timer:SetScale(options.timerSize)
end

--Colours the border: the accent colour for a countdown, otherwise near black
local function SetHighlight(frame, accent)
    if accent then
        local r, g, b = ns:GetAccent()
        frame.setBorder(r, g, b, 1)
    else
        frame.setBorder(0, 0, 0, 1)
    end
end

local function CreateDisplayFrame(index)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(1, 1)
    frame:SetFrameStrata("TOOLTIP")

    --The icon in a 1px border, with the bar at its bottom
    frame.box = CreateFrame("Frame", nil, frame)
    frame.box:SetPoint("CENTER")
    frame.boxBackground = ns:Fill(frame.box, { 0, 0, 0, 0.6 })
    frame.setBorder = ns:Border(frame.box, { 0, 0, 0, 1 })
    frame.icon = frame.box:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.bar = frame.box:CreateTexture(nil, "OVERLAY")
    frame.bar:SetHeight(BAR_HEIGHT)
    frame.bar:SetPoint("BOTTOMLEFT", 1, 1)
    frame.timer = frame.box:CreateFontString(nil, "OVERLAY")
    frame.timer:SetPoint("CENTER", frame.icon, "CENTER")
    frame.timer:SetShadowColor(0, 0, 0, 1)
    frame.timer:SetShadowOffset(1, -1)

    --The text on a dark strip below the icon
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("TOP", frame.box, "BOTTOM", 0, -6)
    frame.text:SetShadowColor(0, 0, 0, 1)
    frame.text:SetShadowOffset(1, -1)
    frame.textBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.textBackground:SetPoint("TOPLEFT", frame.text, "TOPLEFT", -8, 4)
    frame.textBackground:SetPoint("BOTTOMRIGHT", frame.text, "BOTTOMRIGHT", 8, -4)
    frame.textBackground:SetColorTexture(ns.theme.window[1], ns.theme.window[2], ns.theme.window[3], 0.75)

    frame.busy = false
    ns.frames[index] = frame
    StyleFrame(frame)
    PlaceFrame(index)
    frame.box:Hide()
    frame.textBackground:Hide()
    return frame
end

local function ClearFrame(frame)
    frame:SetScript("OnUpdate", nil)
    frame.text:SetText("")
    frame.timer:SetText("")
    frame.icon:SetTexture(nil)
    frame.box:Hide()
    frame.textBackground:Hide()
    frame:SetAlpha(1)
    frame.busy = false
end

--Shows a reminder on a frame. showSeconds is how long it shows, nil to keep it until it is cleared
local function FillFrame(frame, text, icon, countdown, showSeconds, timerText)
    frame.busy = true
    frame.text:SetText(text)
    frame.icon:SetTexture(icon)
    frame.box:Show()
    frame.textBackground:SetShown(text ~= nil and text ~= "")
    SetHighlight(frame, countdown)
    local r, g, b = ns:GetAccent()
    frame.bar:SetColorTexture(r, g, b, 0.9)
    local barWidth = math.max(1, (frame.box:GetWidth() or 2) - 2)
    frame.bar:SetWidth(barWidth)
    frame.timer:SetText(timerText or "")
    if not showSeconds then
        frame:SetScript("OnUpdate", nil)
        frame:SetAlpha(1)
        return
    end
    local start = GetTime()
    local hideTime = start + showSeconds
    frame:SetAlpha(0)
    frame:SetScript("OnUpdate", function(self)
        local now = GetTime()
        local left = math.max(0, hideTime - now)
        local shown = now - start
        if shown < FADE_IN then
            self:SetAlpha(shown / FADE_IN)
        elseif left < FADE_OUT then
            self:SetAlpha(left / FADE_OUT)
        else
            self:SetAlpha(1)
        end
        self.bar:SetWidth(math.max(0.01, barWidth * left / showSeconds))
        if countdown then
            self.timer:SetText(string.format('%.1f', left))
        end
    end)
end

--The first display that isn't showing a reminder, creating a new one when all are in use
local function GetFreeFrame()
    local index = 1
    while ns.frames[index] and ns.frames[index].busy do
        index = index + 1
    end
    return ns.frames[index] or CreateDisplayFrame(index)
end

--Shows a reminder for a few seconds and speaks it
function ns:ShowReminder(reminder)
    local frame = GetFreeFrame()
    FillFrame(frame, reminder.text, reminder.icon, reminder.countdown, SHOW_SECONDS)
    C_Timer.NewTimer(SHOW_SECONDS, function()
        ClearFrame(frame)
    end)
    ns:SendTts(reminder.tts or reminder.text)
    ns:PlayReminderSound(reminder)
end

--Applies changed display options to the displays that exist
function ns:ResetDisplay()
    for index, frame in ipairs(ns.frames) do
        StyleFrame(frame)
        PlaceFrame(index)
    end
    if ns.db.options.toggleDisplay then
        ns:ShowPreview()
    end
end

function ns:SendTts(text)
    local options = ns.db.options
    if options.ttsEnabled then
        C_VoiceChat.SpeakText(options.ttsVoice, text, options.ttsRate, options.ttsVolume)
    end
end

local PREVIEW = {
    { text = "Start ramp: Pain, Shield, Flash Heal", spell = 589 },
    { text = "Power Word: Barrier Soon", spell = 62618, countdown = true, timer = "2.3" },
    { text = "Evangelism", spell = 472433 }
}

--Example reminders on the first three displays, kept until the preview is turned off
function ns:ShowPreview()
    for index, example in ipairs(PREVIEW) do
        local frame = ns.frames[index] or CreateDisplayFrame(index)
        local info = C_Spell.GetSpellInfo(example.spell)
        FillFrame(frame, example.text, info and info.iconID or 134400, example.countdown, nil, example.timer)
        frame.bar:SetWidth(math.max(1, (frame.box:GetWidth() or 2) - 2) * 0.6)
    end
end

--Shows example reminders to position them, or hides them again
function ns:ToggleDisplay()
    local showing = not ns.db.options.toggleDisplay
    ns.db.options.toggleDisplay = showing
    if showing then
        ns:ShowPreview()
    else
        for index = 1, #PREVIEW do
            if ns.frames[index] then
                ClearFrame(ns.frames[index])
            end
        end
    end
end

--Sounds a reminder can play: a few of the game's own, and sounds other addons share through LibSharedMedia
local GAME_SOUNDS = {
    { key = 'RAID_WARNING', name = "Raid warning", id = 8959 },
    { key = 'READY_CHECK', name = "Ready check", id = 8960 },
    { key = 'ALARM_CLOCK_WARNING_3', name = "Alarm", id = 12889 },
    { key = 'UI_RAID_BOSS_WHISPER_WARNING', name = "Boss whisper", id = 37666 },
    { key = 'MAP_PING', name = "Map ping", id = 3175 }
}
local MAX_SHARED_SOUNDS = 15

local function SharedMedia()
    if type(_G.LibStub) ~= 'function' then
        return nil
    end
    local ok, media = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
    if ok and type(media) == 'table' and type(media.List) == 'function' and type(media.Fetch) == 'function' then
        return media
    end
end

--The sounds to pick from, { value, text, header }, for a menu
function ns:SoundMenuItems()
    local items = { { text = "No sound", value = 'none' }, { text = "Game sounds", header = true } }
    for _, sound in ipairs(GAME_SOUNDS) do
        table.insert(items, { text = sound.name, value = 'game:' .. sound.key })
    end
    local media = SharedMedia()
    local shared = media and media:List("sound") or {}
    if #shared > 0 then
        table.insert(items, { text = "Shared media", header = true })
        for index, name in ipairs(shared) do
            if index > MAX_SHARED_SOUNDS then
                break
            end
            if name ~= "None" then
                table.insert(items, { text = name, value = 'media:' .. name })
            end
        end
    end
    return items
end

function ns:SoundName(value)
    if value == nil or value == 'none' then
        return "No sound"
    end
    for _, sound in ipairs(GAME_SOUNDS) do
        if value == 'game:' .. sound.key then
            return sound.name
        end
    end
    return (value:gsub('^media:', ''))
end

function ns:PlaySoundChoice(value)
    if value == nil or value == 'none' then
        return
    end
    local key = value:match('^game:(.+)$')
    if key then
        for _, sound in ipairs(GAME_SOUNDS) do
            if sound.key == key then
                PlaySound((SOUNDKIT and SOUNDKIT[key]) or sound.id, "Master")
            end
        end
        return
    end
    local name = value:match('^media:(.+)$')
    local media = name and SharedMedia()
    local path = media and media:Fetch("sound", name, true)
    if path then
        PlaySoundFile(path, "Master")
    end
end

--Plays the reminder sound, for every reminder or only for the press (the step at the ramp's or spell's time)
function ns:PlayReminderSound(reminder)
    local options = ns.db.options
    if options.soundOn == 'press' and ((reminder.offset or 0) ~= 0 or reminder.chargesOf) then
        return
    end
    ns:PlaySoundChoice(options.sound)
end
