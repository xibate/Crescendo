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
    page.spokenCountdown = Check(left, "Count down the last seconds before a press", 'spokenCountdown',
        "Says 3, 2, 1 before the press of a ramp or spell, starting lower when a step of it is spoken at the same time, like " ..
        "a spell's Soon. Needs Speak the reminders on the Display page.", -240)

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(COLUMN_W)
    local plansLabel = ns:SectionLabel(right, "Save plans")
    plansLabel:SetPoint("TOPLEFT", 0, 0)
    ns:HelpIcon(right, "Save plans", "For all characters: every character uses the same plans and assignments.\n\n" ..
        "For this character: this character keeps its own plans. The first time, it starts with a copy of the plans for all " ..
        "characters. Switching back uses the plans for all characters again, this character's own plans are kept for later."):SetPoint("LEFT", plansLabel, "RIGHT", 4, 0)
    page.plansSaved = Add(ns:Segmented(right, {
        { text = "For all characters", value = false },
        { text = "For this character", value = true }
    }, COLUMN_W, 26, function() return ns:ArePlansPerCharacter() end, function(perCharacter)
        ns:SetPlansPerCharacter(perCharacter)
        ns:RefreshWindow()
    end))
    page.plansSaved:SetPoint("TOPLEFT", 0, -18)

    ns:SectionLabel(right, "Commands"):SetPoint("TOPLEFT", 0, -70)
    local commands = ns:Text(right, 11, theme.dim)
    commands:SetPoint("TOPLEFT", 0, -88)
    commands:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    commands:SetWordWrap(true)
    commands:SetJustifyV("TOP")
    commands:SetSpacing(4)
    commands:SetText(COMMANDS)

    function page.Refresh()
        for _, widget in ipairs(page.widgets) do
            widget:Refresh()
        end
    end
end

ns:RegisterPage('general', "General", 5, Build, function()
    page.Refresh()
end, { icon = 'rail-general' })

--For tests
function ns:GetGeneralPageWidgets()
    return page
end
