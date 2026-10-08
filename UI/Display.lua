local _, ns = ...

--Reminder displays: an icon with the text below it and an optional countdown on top. Extra displays are added next to
--the first one, in the grow direction, when several reminders show at once
ns.frames = {}

local SHOW_SECONDS = 3

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
    frame.icon:SetSize(options.iconSizeW, options.iconSizeH)
    frame.text:SetScale(options.textSize)
    frame.timer:SetScale(options.timerSize)
end

local function CreateDisplayFrame(index)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(1, 1)
    frame:SetFrameStrata("TOOLTIP")
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", frame.icon, "BOTTOM")
    frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.timer:SetPoint("CENTER", frame.icon, "CENTER")
    for _, fontString in ipairs({ frame.text, frame.timer }) do
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(-2, -2)
    end
    frame.busy = false
    ns.frames[index] = frame
    StyleFrame(frame)
    PlaceFrame(index)
    return frame
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
    frame.busy = true
    frame.text:SetText(reminder.text)
    frame.icon:SetTexture(reminder.icon)
    local countdown
    if reminder.countdown then
        local hideTime = GetTime() + SHOW_SECONDS
        countdown = C_Timer.NewTicker(0.01, function()
            frame.timer:SetText(string.format('%.1f', hideTime - GetTime()))
        end)
    end
    C_Timer.NewTimer(SHOW_SECONDS, function()
        frame.text:SetText("")
        frame.icon:SetTexture(nil)
        frame.busy = false
        if countdown then
            countdown:Cancel()
            frame.timer:SetText("")
        end
    end)
    ns:SendTts(reminder.tts or reminder.text)
end

--Applies changed display options to the displays that exist
function ns:ResetDisplay()
    for index, frame in ipairs(ns.frames) do
        StyleFrame(frame)
        PlaceFrame(index)
    end
end

function ns:SendTts(text)
    local options = ns.db.options
    if options.ttsEnabled then
        C_VoiceChat.SpeakText(options.ttsVoice, text, options.ttsRate, options.ttsVolume)
    end
end

--Shows example reminders on the first three displays to position them, or hides them again
function ns:ToggleDisplay()
    local showing = not ns.db.options.toggleDisplay
    ns.db.options.toggleDisplay = showing
    for index = 1, 3 do
        local frame = ns.frames[index] or CreateDisplayFrame(index)
        frame.text:SetText(showing and 'Ramp Helper' or '')
        frame.icon:SetTexture(showing and 450907 or nil)
        frame.timer:SetText(showing and '2.3' or '')
        frame.busy = showing
    end
end
