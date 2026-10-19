local _, ns = ...

--The Display page: where and how big the reminders show, the voice that speaks them, and the reminder and MRT note options

local theme = ns.theme
local COLUMN_W = 440
local SLIDER_W = 440

local page

local function Options()
    return ns.db.options
end

--get and set for a display option. Changing a display option redraws the displays
local function Option(key, redraw)
    return function()
        return Options()[key]
    end, function(value)
        Options()[key] = value
        if redraw then
            ns:ResetDisplay()
        end
    end
end

local function VoiceName()
    for _, voice in pairs(C_VoiceChat.GetTtsVoices() or {}) do
        if voice.voiceID == Options().ttsVoice then
            return voice.name
        end
    end
    return "Voice " .. tostring(Options().ttsVoice)
end

local function VoiceItems()
    local items = {}
    for _, voice in pairs(C_VoiceChat.GetTtsVoices() or {}) do
        table.insert(items, { text = voice.name, value = voice.voiceID })
    end
    return items
end

local function Build(frame)
    page = { frame = frame, widgets = {} }
    local function Add(widget)
        table.insert(page.widgets, widget)
        return widget
    end

    --Left: the reminder display
    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(COLUMN_W)
    ns:SectionLabel(left, "Reminder display"):SetPoint("TOPLEFT", 0, 0)
    page.unlock = ns:Button(left, "Unlock", 100, 26, function()
        ns:SetUnlocked(true)
    end, true)
    page.unlock:SetPoint("TOPLEFT", 0, -18)
    ns:Tooltip(page.unlock, "Unlock", "Dims the screen under a grid and shows the reminders with a box to drag them where you want, " ..
        "like EllesmereUI's unlock mode. Lock them with the toolbar, Escape or by entering combat. Also /cres unlock.")
    page.preview = ns:Button(left, "Show preview", 120, 26, function()
        ns:ToggleDisplay()
        page.Refresh()
    end, true)
    page.preview:SetPoint("LEFT", page.unlock, "RIGHT", 6, 0)
    ns:Tooltip(page.preview, "Preview", "Shows three example reminders where they will show, so you can place and size them. The sliders move them while they show.")
    page.grow = Add(ns:Segmented(left, {
        { text = "Up", value = 'top' },
        { text = "Down", value = 'bottom' },
        { text = "Left", value = 'left' },
        { text = "Right", value = 'right' }
    }, 210, 26, (Option('growDirection')), select(2, Option('growDirection', true))))
    page.grow:SetPoint("TOPRIGHT", 0, -18)
    local growLabel = ns:Text(left, 10, theme.dim, "LEFT")
    growLabel:SetPoint("BOTTOMLEFT", page.grow, "TOPLEFT", 0, 4)
    growLabel:SetText("Grow direction")

    local sliders = {
        { "Position X", -1000, 1000, 1, 'framePositionX' },
        { "Position Y", -1000, 1000, 1, 'framePositionY' },
        { "Icon width", 10, 200, 1, 'iconSizeW' },
        { "Icon height", 10, 200, 1, 'iconSizeH' },
        { "Text size", 0.5, 5, 0.1, 'textSize' },
        { "Countdown size", 0.5, 5, 0.1, 'timerSize' },
        { "Space between reminders", 0, 300, 1, 'displaySpacing' }
    }
    local y = -60
    page.sliders = {}
    for _, info in ipairs(sliders) do
        local get, set = Option(info[5], true)
        local slider = Add(ns:Slider(left, info[1], SLIDER_W, info[2], info[3], info[4], get, set))
        slider:SetPoint("TOPLEFT", 0, y)
        page.sliders[info[5]] = slider
        y = y - 52
    end

    --Where plans are saved
    local plansLabel = ns:SectionLabel(left, "Save plans")
    plansLabel:SetPoint("TOPLEFT", 0, y - 14)
    ns:HelpIcon(left, "Save plans", "For all characters: every character uses the same plans and assignments.\n\n" ..
        "For this character: this character keeps its own plans. The first time, it starts with a copy of the plans for all " ..
        "characters. Switching back uses the plans for all characters again, this character's own plans are kept for later."):SetPoint("LEFT", plansLabel, "RIGHT", 4, 0)
    page.plansSaved = Add(ns:Segmented(left, {
        { text = "For all characters", value = false },
        { text = "For this character", value = true }
    }, SLIDER_W, 26, function() return ns:ArePlansPerCharacter() end, function(perCharacter)
        ns:SetPlansPerCharacter(perCharacter)
        if ns.RefreshWindow then
            ns:RefreshWindow()
        end
    end))
    page.plansSaved:SetPoint("TOPLEFT", 0, y - 30)

    --Right: voice, reminders and MRT notes
    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(COLUMN_W)
    ns:SectionLabel(right, "Voice"):SetPoint("TOPLEFT", 0, 0)
    page.tts = Add(ns:Checkbox(right, "Speak the reminders", Option('ttsEnabled')))
    page.tts:SetPoint("TOPLEFT", 0, -20)
    page.play = ns:Button(right, "Play voice", 110, 24, function()
        ns:SendTts('Crescendo')
    end)
    page.play:SetPoint("TOPRIGHT", 0, -18)
    ns:Tooltip(page.play, "Play voice", "Speaks a test message, when speaking is on.")
    local voiceLabel = ns:Text(right, 11, theme.dim)
    voiceLabel:SetPoint("TOPLEFT", 0, -52)
    voiceLabel:SetText("Voice")
    page.voice = Add(ns:Dropdown(right, COLUMN_W, 24, VoiceName, VoiceItems, select(2, Option('ttsVoice'))))
    page.voice:SetPoint("TOPLEFT", 0, -68)
    page.rate = Add(ns:Slider(right, "Speed", COLUMN_W, -10, 10, 1, Option('ttsRate')))
    page.rate:SetPoint("TOPLEFT", 0, -100)
    page.volume = Add(ns:Slider(right, "Volume", COLUMN_W, 0, 100, 1, Option('ttsVolume')))
    page.volume:SetPoint("TOPLEFT", 0, -150)

    ns:SectionLabel(right, "Reminders"):SetPoint("TOPLEFT", 0, -210)
    local getSetupOnly, setSetupOnly = Option('preReqsOnly')
    page.setupOnly = Add(ns:Checkbox(right, "Only setup steps", getSetupOnly, setSetupOnly,
        "Leave out the final press of each ramp and only show the steps marked as setup, for when another addon or weakaura already warns you about the press."))
    page.setupOnly:SetPoint("TOPLEFT", 0, -230)
    local getCountdown, setCountdown = Option('timerDuration')
    page.countdown = Add(ns:Slider(right, "Spell countdown (seconds)", COLUMN_W, 2, 10, 1, getCountdown, setCountdown,
        "How many seconds before a spell in the plan its countdown starts. Ramps have their own steps."))
    page.countdown:SetPoint("TOPLEFT", 0, -282)
    local getHide, setHide = Option('hideOnCooldown')
    page.hideOnCooldown = Add(ns:Checkbox(right, "Hide reminders while the spell or trinket is on cooldown", getHide, setHide,
        "Leaves out the reminders of a ramp, spell or trinket that won't be ready by the time it should land. A ramp goes by " ..
        "the spell set for it on the Ramps page.\n\nDuring boss fights the game can hide cooldowns from addons. Then it goes " ..
        "by when you last cast the spell, and when it can't tell, the reminder shows."))
    page.hideOnCooldown:SetWidth(COLUMN_W)
    page.hideOnCooldown:SetPoint("TOPLEFT", 0, -254)

    ns:SectionLabel(right, "MRT notes"):SetPoint("TOPLEFT", 0, -342)
    page.mainNote = Add(ns:Checkbox(right, "Take my times from the main MRT note", Option('readFromNote')))
    page.mainNote:SetPoint("TOPLEFT", 0, -362)
    page.personalNote = Add(ns:Checkbox(right, "Take my times from my personal MRT note", Option('mrtPersonalNote')))
    page.personalNote:SetPoint("TOPLEFT", 0, -386)
    local noteHelp = ns:Text(right, 10, theme.dim)
    noteHelp:SetPoint("TOPLEFT", 0, -412)
    noteHelp:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    noteHelp:SetWordWrap(true)
    noteHelp:SetText("With one of these on, the times of your plans are replaced by your lines in the note during the " ..
        "pull. Boss ability assignments still apply.")

    page.reset = ns:ConfirmButton(right, "Reset to defaults", "Click again to reset", 160, 26, function()
        ns:ResetOptions()
        ns:ResetDisplay()
        page.Refresh()
    end)
    page.reset:SetPoint("BOTTOMRIGHT", 0, 0)
    ns:Tooltip(page.reset, "Reset to defaults", "Puts the display, voice, reminder and MRT note settings back. Plans and ramps stay.")

    function page.Refresh()
        for _, widget in ipairs(page.widgets) do
            widget:Refresh()
        end
        page.preview.label:SetText(Options().toggleDisplay and "Hide preview" or "Show preview")
    end
end

ns:RegisterPage('display', "Display", 3, Build, function()
    page.Refresh()
end)

--For tests
function ns:GetDisplayPageWidgets()
    return page
end
