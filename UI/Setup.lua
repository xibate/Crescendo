local _, ns = ...

--The setup guide: four short steps the first time the window opens (and with /cres setup): what Crescendo needs, how
--reminders are heard, where they show, and where plans come from. What is done is kept in CrescendoDB.setup, and a
--checklist on the Plans page shows what is left until everything is done

local theme = ns.theme
local STEPS = 4
local guide

local function Setup()
    return ns.db.setup
end

local function Options()
    return ns.db.options
end

--The boss mod Crescendo follows, nil without one
function ns:BossModName()
    if BigWigsLoader then
        return "BigWigs"
    elseif DBM then
        return "DBM"
    end
    return nil
end

--Says a test reminder, and remembers that the voice was tried
function ns:TestVoice()
    if not Options().ttsEnabled then
        ns:WriteOutput("Speaking is off: tick Speak the reminders first")
        return false
    end
    ns:SendTts("Crescendo. Power Word: Barrier Soon")
    Setup().voiceTested = true
    ns:RefreshChecklist()
    return true
end

--True when the profile in use has any plan
local function HasPlan()
    for _, difficulties in pairs(ns.db.plans or {}) do
        for _, bosses in pairs(type(difficulties) == 'table' and difficulties or {}) do
            for _, text in pairs(type(bosses) == 'table' and bosses or {}) do
                if type(text) == 'string' and text:find('%S') then
                    return true
                end
            end
        end
    end
    return false
end

--What a new player has to do: { key, text, done, action, help }
function ns:SetupChecklist()
    local setup = Setup()
    return {
        { key = 'bossMod', text = "A boss mod: BigWigs or DBM", done = ns:BossModName() ~= nil,
            help = "Crescendo follows their timers to know when each boss ability comes. Install one of them." },
        { key = 'voice', text = "Test the voice", done = setup.voiceTested == true, action = function() ns:TestVoice() end,
            help = "Says a test reminder, so you know you'll hear them." },
        { key = 'placed', text = "Place the reminders", done = setup.placed == true, action = function() ns:SetUnlocked(true) end,
            help = "Move the reminders to where you look during a fight." },
        { key = 'plan', text = "Make or import a plan", done = HasPlan(), action = function() ns:OpenWindow('plans') end,
            help = "Pick an ability and Add assignment, or import plans from your raid in Share." },
        { key = 'tested', text = "Try it once", done = setup.tested == true, action = function() ns:OpenWindow('timeline') end,
            help = "Test cast on Plans, or Replay pull on the Timeline, shows and says the reminders as they would come." },
    }
end

--True while the checklist has something left and wasn't hidden
function ns:ChecklistActive()
    if Setup().checklistHidden then
        return false
    end
    for _, item in ipairs(ns:SetupChecklist()) do
        if not item.done then
            return true
        end
    end
    return false
end

function ns:RefreshChecklist()
    if ns.OnChecklistChanged then
        ns:OnChecklistChanged()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- The guide
------------------------------------------------------------------------------------------------------------------------

local function Paragraph(parent, y, size, color)
    local text = ns:Text(parent, size or 12, color)
    text:SetPoint("TOPLEFT", 0, y)
    text:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    text:SetWordWrap(true)
    text:SetJustifyV("TOP")
    return text
end

local function Finish(page, tab)
    Setup().done = true
    guide:Hide()
    if page then
        if tab then
            ns.db.ui.plannerTab = tab
        end
        ns:OpenWindow(page)
    end
    ns:RefreshChecklist()
end

local function BuildWelcome(step)
    local title = Paragraph(step, 0, 18)
    title:SetText("Welcome to Crescendo")
    local intro = Paragraph(step, -32, 12, theme.text)
    intro:SetText("Crescendo reminds you of your healing cooldowns and ramps at the right moment of a boss fight: it shows " ..
        "them on screen and says them out loud. Four quick steps get you going.")
    step.spec = Paragraph(step, -96, 13)
    step.bossMod = Paragraph(step, -124, 13)
    step.bossModHelp = Paragraph(step, -146, 11, theme.dim)
    function step:Refresh()
        local specKey = ns:GetPlayerSpecKey()
        if specKey then
            step.spec:SetText("Your spec: |cffffffff" .. ns.specNames[specKey] .. "|r")
            step.spec:SetTextColor(ns:GetAccent())
        else
            step.spec:SetText("Crescendo is for healers, it has nothing for your current spec. Plans can still be made for any healer spec.")
            step.spec:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
        end
        local bossMod = ns:BossModName()
        if bossMod then
            step.bossMod:SetText("Boss mod: |cffffffff" .. bossMod .. "|r found")
            step.bossMod:SetTextColor(ns:GetAccent())
            step.bossModHelp:SetText("Crescendo follows its timers to know when each boss ability comes.")
        else
            step.bossMod:SetText("No boss mod found")
            step.bossMod:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
            step.bossModHelp:SetText("Install BigWigs or DBM: Crescendo follows their timers to know when each boss ability comes. " ..
                "Times after the pull work without one.")
        end
    end
end

local function BuildHearing(step)
    Paragraph(step, 0, 18):SetText("Hearing the reminders")
    Paragraph(step, -32, 12, theme.text):SetText("Reminders are said out loud, so you don't have to look for them. " ..
        "Before you press a cooldown you hear its Soon message, or a countdown.")
    step.tts = ns:Checkbox(step, "Speak the reminders", function() return Options().ttsEnabled end, function(value)
        Options().ttsEnabled = value
    end)
    step.tts:SetPoint("TOPLEFT", 0, -82)
    step.test = ns:Button(step, "Test voice", 120, 26, function() ns:TestVoice() end, true)
    step.test:SetPoint("TOPLEFT", 280, -79)
    local say = ns:Text(step, 12)
    say:SetPoint("TOPLEFT", 0, -122)
    say:SetText("Before a press, say")
    step.say = ns:Segmented(step, {
        { text = "Soon", value = false }, { text = "A countdown", value = true }
    }, 300, 26, function() return Options().spokenCountdown == true end, function(value) Options().spokenCountdown = value end)
    step.say:SetPoint("TOPLEFT", 0, -142)
    Paragraph(step, -180, 11, theme.dim):SetText("Soon: \"Power Word: Barrier Soon\" a few seconds before. A countdown: \"5, 4, 3, 2, 1, " ..
        "Power Word: Barrier\". Each assignment can choose for itself too. The voice and its speed are on the Display page.")
    function step:Refresh()
        step.tts:Refresh()
        step.say:Refresh()
    end
end

local function BuildShowing(step)
    Paragraph(step, 0, 18):SetText("Where reminders show")
    Paragraph(step, -32, 12, theme.text):SetText("Reminders show near the middle of the screen. Pick how they look, then " ..
        "move them to where you look during a fight.")
    local style = ns:Text(step, 12)
    style:SetPoint("TOPLEFT", 0, -82)
    style:SetText("Style")
    step.style = ns:Segmented(step, {
        { text = "Icon", value = 'icon' }, { text = "Bar", value = 'bar' }, { text = "Text", value = 'text' }
    }, 300, 26, function() return Options().displayStyle end, function(value)
        Options().displayStyle = value
        ns:ResetDisplay()
    end)
    step.style:SetPoint("TOPLEFT", 0, -102)
    step.move = ns:Button(step, "Move the reminders", 170, 28, function()
        ns.resumeSetupStep = 3
        guide:Hide()
        ns:SetUnlocked(true)
    end, true)
    step.move:SetPoint("TOPLEFT", 0, -146)
    step.moved = ns:Text(step, 12)
    step.moved:SetPoint("LEFT", step.move, "RIGHT", 12, 0)
    Paragraph(step, -190, 11, theme.dim):SetText("Drag them, then Lock (or press Escape) to come back here. Size, colours " ..
        "and sounds are on the Display page.")
    function step:Refresh()
        step.style:Refresh()
        step.moved:SetText(Setup().placed and "Placed" or "")
        step.moved:SetTextColor(ns:GetAccent())
    end
end

local function Choice(parent, x, title, text, buttonText, onClick)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(246, 170)
    box:SetPoint("TOPLEFT", x, -74)
    ns:Fill(box, { 1, 1, 1, 0.03 })
    ns:Border(box, theme.border)
    local heading = ns:Text(box, 14)
    heading:SetPoint("TOPLEFT", 12, -12)
    heading:SetText(title)
    local body = ns:Text(box, 11, theme.dim)
    body:SetPoint("TOPLEFT", 12, -36)
    body:SetPoint("RIGHT", box, "RIGHT", -12, 0)
    body:SetWordWrap(true)
    body:SetJustifyV("TOP")
    body:SetText(text)
    box.button = ns:Button(box, buttonText, 222, 28, onClick, true)
    box.button:SetPoint("BOTTOMLEFT", 12, 12)
    return box
end

local function BuildPlans(step)
    Paragraph(step, 0, 18):SetText("Your plan")
    Paragraph(step, -32, 12, theme.text):SetText("A plan says which cooldown goes on which boss ability. Get it from whoever " ..
        "makes your raid's plans, or make your own.")
    step.import = Choice(step, 0, "Get plans from your raid", "Ask them to click Send to group under Plans, Share: you'll be " ..
        "asked to import. Or paste a plan string they sent you.", "Paste a plan string", function() Finish('plans', 'note') end)
    step.own = Choice(step, 262, "Make my own", "Pick a boss and one of its abilities, then Add assignment. The Timeline shows " ..
        "a recorded pull to assign to any cast.", "Start planning", function() Finish('plans', 'assignments') end)
end

local BUILDERS = { BuildWelcome, BuildHearing, BuildShowing, BuildPlans }

local function ShowStep(index)
    guide.current = index
    for number, step in ipairs(guide.steps) do
        step:SetShown(number == index)
    end
    if guide.steps[index].Refresh then
        guide.steps[index]:Refresh()
    end
    guide.count:SetText(index .. " of " .. STEPS)
    for number, dot in ipairs(guide.dots) do
        local r, g, b = ns:GetAccent()
        dot:SetColorTexture(r, g, b, number <= index and 1 or 0.25)
    end
    guide.back:SetShown(index > 1)
    guide.next:SetShown(index < STEPS)
    guide.later:SetShown(index == STEPS)
end

local function CreateGuide()
    guide = CreateFrame("Frame", "CrescendoSetup", UIParent)
    guide:SetSize(560, 400)
    guide:SetPoint("CENTER", 0, 40)
    guide:SetFrameStrata("FULLSCREEN_DIALOG")
    guide:SetToplevel(true)
    guide:EnableMouse(true)
    guide:SetMovable(true)
    guide:RegisterForDrag("LeftButton")
    guide:SetScript("OnDragStart", guide.StartMoving)
    guide:SetScript("OnDragStop", guide.StopMovingOrSizing)
    table.insert(UISpecialFrames, "CrescendoSetup")
    ns:Fill(guide, theme.window)
    ns:Border(guide, theme.borderStrong)
    local logo = guide:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("TOPLEFT", 16, -14)
    logo:SetTexture("Interface/Addons/Crescendo/Media/logo")
    local title = ns:Text(guide, 13)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("Set up Crescendo")
    title:SetTextColor(ns:GetAccent())
    guide.count = ns:Text(guide, 11, theme.dim, "RIGHT")
    guide.count:SetPoint("TOPRIGHT", -48, -18)
    local close = ns:Button(guide, "x", 24, 24, function()
        Setup().dismissed = true
        guide:Hide()
    end)
    close:SetPoint("TOPRIGHT", -12, -12)
    ns:Tooltip(close, "Close the guide", "Open it again with /cres setup, or from the General page. The checklist on the Plans page shows what is left.")
    local rule = guide:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 1, -48)
    rule:SetPoint("TOPRIGHT", -1, -48)
    rule:SetColorTexture(1, 1, 1, 0.08)

    guide.steps = {}
    for index, build in ipairs(BUILDERS) do
        local step = CreateFrame("Frame", nil, guide)
        step:SetPoint("TOPLEFT", 24, -66)
        step:SetPoint("BOTTOMRIGHT", -24, 60)
        build(step)
        guide.steps[index] = step
    end

    guide.dots = {}
    for index = 1, STEPS do
        local dot = guide:CreateTexture(nil, "ARTWORK")
        dot:SetSize(18, 3)
        dot:SetPoint("BOTTOMLEFT", 24 + (index - 1) * 24, 30)
        guide.dots[index] = dot
    end
    guide.back = ns:Button(guide, "Back", 90, 28, function() ShowStep(guide.current - 1) end)
    guide.back:SetPoint("BOTTOMRIGHT", -126, 16)
    guide.next = ns:Button(guide, "Next", 100, 28, function() ShowStep(guide.current + 1) end, true)
    guide.next:SetPoint("BOTTOMRIGHT", -16, 16)
    guide.later = ns:Button(guide, "Later", 100, 28, function() Finish() end)
    guide.later:SetPoint("BOTTOMRIGHT", -16, 16)
    ns:Tooltip(guide.later, "Later", "Closes the guide. The checklist on the Plans page shows what is left.")
end

--Opens the guide on a step, the first one when none is given
function ns:OpenSetup(step)
    if not guide then
        CreateGuide()
    end
    guide:Show()
    ShowStep(math.max(1, math.min(STEPS, step or 1)))
end

--The first time the window opens, the guide opens with it
function ns:OpenSetupFirstTime()
    local setup = Setup()
    if not setup.done and not setup.dismissed then
        ns:OpenSetup(1)
    end
end

--Unlock mode came back from Move the reminders: the guide opens again where it was
function ns:OnRemindersPlaced()
    Setup().placed = true
    if ns.resumeSetupStep then
        local step = ns.resumeSetupStep
        ns.resumeSetupStep = nil
        ns:OpenSetup(step)
    end
    ns:RefreshChecklist()
end

--For tests
function ns:GetSetupGuide()
    return guide
end
