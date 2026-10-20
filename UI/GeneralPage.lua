local _, ns = ...

--The General page: what the addon does in the raid on its own, during the fight next to the reminders, and where plans
--are saved

local theme = ns.theme
local COLUMN_W = 440

local page

local function Options()
    return ns.db.options
end

local function Option(key, after)
    return function()
        return Options()[key]
    end, function(value)
        Options()[key] = value
        if after then
            after()
        end
    end
end

local COMMANDS = "|cffffd100/cres|r  opens this window\n" ..
    "|cffffd100/cres timeline|r, |cffffd100/cres ramps|r, |cffffd100/cres display|r, |cffffd100/cres general|r  open a page\n" ..
    "|cffffd100/cres unlock|r  moves the reminders and the Next up strip\n" ..
    "|cffffd100/cres review|r  shows the review of the last pull\n" ..
    "|cffffd100/cres setup|r  opens the setup guide\n" ..
    "|cffffd100/cres phase 2|r  starts stage 2 by hand, without a boss mod\n" ..
    "|cffffd100/cres stop|r  stops a test"

local function Build(frame)
    page = { frame = frame, widgets = {} }
    local function Add(widget)
        table.insert(page.widgets, widget)
        return widget
    end
    local function Check(parent, label, key, tooltip, y, after)
        local get, set = Option(key, after)
        local check = Add(ns:Checkbox(parent, label, get, set, tooltip))
        check:SetWidth(COLUMN_W)
        check:SetPoint("TOPLEFT", 0, y)
        return check
    end

    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(COLUMN_W)
    ns:SectionLabel(left, "In the raid"):SetPoint("TOPLEFT", 0, 0)
    page.followRaid = Check(left, "Open on the boss I'm at", 'followRaid',
        "In a raid, the planner opens on the boss you target, or else the next boss that isn't dead this lockout, on that " ..
        "difficulty and for your spec.", -20)
    page.readyCheck = Check(left, "Check my plan at a ready check", 'readyCheck',
        "At a ready check, a line in chat with your plan for the boss you are about to pull, and what is wrong with it: no " ..
        "plan, spells you don't have talented, trinkets you don't wear, cooldowns that won't be ready.", -44)
    page.review = Check(left, "Review each pull", 'review',
        "After a pull, a window with what was left out because it was on cooldown and what never triggered, with why. When " ..
        "all reminders showed, a line in chat says so.", -68)
    page.lastReview = ns:Button(left, "Show the last review", 170, 24, function() ns:OpenPullReview() end)
    page.lastReview:SetPoint("TOPLEFT", 24, -94)

    ns:SectionLabel(left, "During the fight"):SetPoint("TOPLEFT", 0, -140)
    page.nextUp = Check(left, "Show what's next", 'nextUp',
        "A strip with your next presses and how long until each, so you see them coming before their reminder shows. Move it " ..
        "with Unlock on the Display page.", -160, function() ns:RefreshNextUp() end)
    local getCount, setCount = Option('nextUpCount', function()
        ns:ResetNextUp()
        ns:RefreshNextUp()
    end)
    page.nextUpCount = Add(ns:Slider(left, "How many to show", COLUMN_W - 24, 1, 5, 1, getCount, setCount))
    page.nextUpCount:SetPoint("TOPLEFT", 24, -186)
    --Before a press: the spell's Soon message, or a spoken countdown in its place
    local sayLabel = ns:Text(left, 12)
    sayLabel:SetPoint("TOPLEFT", 0, -242)
    sayLabel:SetText("Before a press, say")
    local getSay, setSay = Option('spokenCountdown')
    page.beforePress = Add(ns:Segmented(left, {
        { text = "Soon", value = false, tooltip = "Says the Soon message of a spell or trinket, like Power Word: Barrier Soon, " ..
            "a few seconds before it. Set how many seconds with Spell countdown on the Display page." },
        { text = "A countdown", value = true, tooltip = "Says 5, 4, 3, 2, 1 before the press of a ramp or spell instead, a " ..
            "moment early so the words land on time. The Soon message still shows, without being spoken. A number is left " ..
            "out while another step of a ramp is spoken." }
    }, COLUMN_W - 24, 24, function() return getSay() == true end, function(value) setSay(value) end))
    page.beforePress:SetPoint("TOPLEFT", 0, -262)
    local getFrom, setFrom = Option('countdownFrom')
    page.countdownFrom = Add(ns:Slider(left, "Count down from", COLUMN_W - 24, 3, 10, 1, getFrom, setFrom,
        "The first number of the countdown, in seconds before the press."))
    page.countdownFrom:SetPoint("TOPLEFT", 24, -296)
    local getLead, setLead = Option('countdownLead')
    page.countdownLead = Add(ns:Slider(left, "Say each number early by (seconds)", COLUMN_W - 24, 0, 1.5, 0.1, getLead, setLead,
        "Speech starts a moment after it is asked for. Raise this when the numbers come late, lower it when they come early."))
    page.countdownLead:SetPoint("TOPLEFT", 24, -342)

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(COLUMN_W)
    --Profiles: plans, ramps and settings in named sets, chosen per character
    local profileLabel = ns:SectionLabel(right, "Profile")
    profileLabel:SetPoint("TOPLEFT", 0, 0)
    ns:HelpIcon(right, "Profiles", "A profile keeps plans, plan history, ramps and settings together. Every character uses " ..
        "Default until you pick another, so characters can share a profile or each have their own. Recorded pulls and the " ..
        "cooldowns the addon learned are kept for every profile."):SetPoint("LEFT", profileLabel, "RIGHT", 4, 0)
    local function Status(text, color)
        page.profileStatus:SetText(text or '')
        if color == 'error' then
            page.profileStatus:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
        else
            page.profileStatus:SetTextColor(ns:GetAccent())
        end
    end
    local function Changed(text)
        ns:ResetDisplay()
        ns:RefreshNextUp()
        ns:RefreshWindow()
        Status(text)
    end
    local function OtherProfiles(withDefault)
        local items = {}
        for _, name in ipairs(ns:ProfileNames()) do
            if name ~= ns:CurrentProfile() and (withDefault or name ~= 'Default') then
                table.insert(items, { text = name, value = name })
            end
        end
        if #items == 0 then
            table.insert(items, { text = "No other profiles", header = true })
        end
        return items
    end
    page.profile = Add(ns:Dropdown(right, 250, 26, function() return ns:CurrentProfile() end, function()
        local items = { { text = "Use profile", header = true } }
        for _, name in ipairs(ns:ProfileNames()) do
            table.insert(items, { text = name, value = name })
        end
        return items
    end, function(name)
        ns:UseProfile(name)
        Changed("Using " .. name)
    end))
    page.profile:SetPoint("TOPLEFT", 0, -18)
    page.profileUsers = ns:Text(right, 11, theme.dim)
    page.profileUsers:SetPoint("LEFT", page.profile, "RIGHT", 10, 0)

    page.newProfile = ns:EditBox(right, 250, 26)
    page.newProfile:SetPoint("TOPLEFT", 0, -52)
    page.newProfile:SetPlaceholder("New profile name")
    page.createProfile = ns:Button(right, "Create", 90, 26, function()
        local name = page.newProfile:GetText()
        local ok, problem = ns:CreateProfile(name)
        if ok then
            page.newProfile:SetValue('')
            page.newProfile:ClearFocus()
            Changed("Created and using " .. ns:CurrentProfile() .. ", with the default settings and starter ramps")
        else
            Status(problem, 'error')
        end
    end, true)
    page.createProfile:SetPoint("LEFT", page.newProfile, "RIGHT", 8, 0)

    page.copyFrom = Add(ns:Dropdown(right, 250, 26, function() return page.copySource or "Copy from..." end,
        function() return OtherProfiles(true) end, function(name) page.copySource = name end))
    page.copyFrom:SetPoint("TOPLEFT", 0, -86)
    page.copyProfile = ns:ConfirmButton(right, "Copy", "Replace this one?", 140, 26, function()
        if page.copySource and ns:CopyProfile(page.copySource) then
            Changed("Copied " .. page.copySource .. " into " .. ns:CurrentProfile())
            page.copySource = nil
            page.Refresh()
        else
            Status("Pick a profile to copy from first", 'error')
        end
    end)
    page.copyProfile:SetPoint("LEFT", page.copyFrom, "RIGHT", 8, 0)
    ns:Tooltip(page.copyProfile, "Copy", "Replaces the plans, ramps and settings of the profile in use with those of the one picked. Click twice.")

    page.deleteFrom = Add(ns:Dropdown(right, 250, 26, function() return page.deleteTarget or "Delete a profile..." end,
        function() return OtherProfiles(false) end, function(name) page.deleteTarget = name end))
    page.deleteFrom:SetPoint("TOPLEFT", 0, -120)
    page.deleteProfile = ns:ConfirmButton(right, "Delete", "Delete it?", 140, 26, function()
        if page.deleteTarget and ns:DeleteProfile(page.deleteTarget) then
            Status("Deleted " .. page.deleteTarget)
            page.deleteTarget = nil
            page.Refresh()
        else
            Status("Pick a profile to delete first, not the one in use or Default", 'error')
        end
    end)
    page.deleteProfile:SetPoint("LEFT", page.deleteFrom, "RIGHT", 8, 0)

    page.resetProfile = ns:ConfirmButton(right, "Reset this profile", "Click to reset", 180, 26, function()
        ns:ResetProfile()
        Changed("Reset " .. ns:CurrentProfile() .. " to the default settings and starter ramps, without plans")
    end)
    page.resetProfile:SetPoint("TOPLEFT", 0, -154)
    ns:Tooltip(page.resetProfile, "Reset this profile", "Puts the settings and ramps back to the defaults and removes its plans. Click twice.")
    page.profileStatus = ns:Text(right, 11, theme.dim)
    page.profileStatus:SetPoint("TOPLEFT", 0, -188)
    page.profileStatus:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    page.profileStatus:SetWordWrap(true)

    --The look of the window and the reminders
    ns:SectionLabel(right, "Look"):SetPoint("TOPLEFT", 0, -222)
    page.accent = Add(ns:Segmented(right, {
        { text = "EllesmereUI colour", value = 'ellesmere', tooltip = "The accent colour set in EllesmereUI, or Crescendo's aqua without EllesmereUI." },
        { text = "Crescendo aqua", value = 'crescendo', tooltip = "Crescendo's own aqua green." },
        { text = "Own colour...", value = 'custom', tooltip = "A colour you pick." }
    }, COLUMN_W, 26, function() return Options().accentSource end, function(source)
        Options().accentSource = source
        if source == 'custom' then
            ns:PickAccentColor(function() Changed() end)
        end
        Changed()
    end))
    page.accent:SetPoint("TOPLEFT", 0, -240)
    local getScale, setScale = Option('windowScale', function() ns:SetWindowScale(Options().windowScale) end)
    page.windowScale = Add(ns:Slider(right, "Window scale", COLUMN_W, 0.6, 1.5, 0.05, getScale, setScale,
        "How big the window is drawn, on top of the game's UI scale."))
    page.windowScale:SetPoint("TOPLEFT", 0, -276)

    page.setupGuide = ns:Button(right, "Open the setup guide", 180, 26, function() ns:OpenSetup(1) end)
    page.setupGuide:SetPoint("TOPLEFT", 0, -330)
    page.showChecklist = ns:Button(right, "Show the checklist", 160, 26, function()
        ns.db.setup.checklistHidden = nil
        ns:OpenWindow('plans')
    end)
    page.showChecklist:SetPoint("LEFT", page.setupGuide, "RIGHT", 8, 0)
    ns:Tooltip(page.showChecklist, "Getting started", "The checklist on the Plans page with what is left to set up.")

    ns:SectionLabel(right, "Commands"):SetPoint("TOPLEFT", 0, -372)
    local commands = ns:Text(right, 11, theme.dim)
    commands:SetPoint("TOPLEFT", 0, -390)
    commands:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    commands:SetWordWrap(true)
    commands:SetJustifyV("TOP")
    commands:SetSpacing(4)
    commands:SetText(COMMANDS)

    function page.Refresh()
        for _, widget in ipairs(page.widgets) do
            widget:Refresh()
        end
        local users = ns:ProfileUsers(ns:CurrentProfile())
        page.profileUsers:SetText(users and (users == 1 and "used by this character" or ("used by " .. users .. " characters")) or
            "for every character without one")
    end
end

ns:RegisterPage('general', "General", 5, Build, function()
    page.Refresh()
end, { icon = 'rail-general' })

--For tests
function ns:GetGeneralPageWidgets()
    return page
end
