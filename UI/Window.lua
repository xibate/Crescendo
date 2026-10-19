local _, ns = ...

--The addon's window (/cres): a header with the pages (Plans, Ramps, Display) and a page below it. Pages register with
--ns:RegisterPage and are built the first time they show

local theme = ns.theme
local WIDTH, HEIGHT = 960, 600
local HEADER = 48
ns.windowPadding = 14

local window
local pages = {}

--build(frame) creates the page in its frame, refresh() redraws it from the saved settings
function ns:RegisterPage(key, title, order, build, refresh)
    table.insert(pages, { key = key, title = title, order = order, build = build, refresh = refresh })
    table.sort(pages, function(a, b) return a.order < b.order end)
end

local function UI()
    return ns.db.ui
end

local function PageInfo(key)
    for _, page in ipairs(pages) do
        if page.key == key then
            return page
        end
    end
end

local function UpdateNav()
    local r, g, b = ns:GetAccent()
    for _, button in ipairs(window.nav) do
        local active = button.key == UI().page
        button.label:SetTextColor(1, 1, 1, active and 1 or 0.5)
        button.underline:SetColorTexture(r, g, b, active and 1 or 0)
    end
end

--Shows how long a running test has to go, with a button to stop it
local testTicker
function ns:RefreshTestStatus()
    if not window then
        return
    end
    local testing = ns:IsTesting()
    window.testStatus:SetShown(testing)
    window.stopTest:SetShown(testing)
    if testing then
        local test = ns.fight.test
        local elapsed = GetTime() - ns.fight.start
        local what = test.ability and ("Testing " .. test.ability) or "Testing recorded pull"
        window.testStatus:SetText(what .. "  " .. ns:FormatTime(elapsed) .. " / " .. ns:FormatTime(test.duration))
        if not testTicker then
            testTicker = C_Timer.NewTicker(0.5, function() ns:RefreshTestStatus() end)
        end
    elseif testTicker then
        testTicker:Cancel()
        testTicker = nil
    end
    local page = PageInfo(UI().page)
    if page and page.onTestChanged then
        page.onTestChanged()
    end
end

function ns:SetPageTestHandler(key, handler)
    PageInfo(key).onTestChanged = handler
end

local function CreateWindow()
    local frame = CreateFrame("Frame", "CrescendoWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        UI().windowPoint = { point, relativePoint, x, y }
    end)
    frame:SetScript("OnHide", function()
        ns:CloseMenu()
    end)
    table.insert(UISpecialFrames, "CrescendoWindow")
    ns:Fill(frame, theme.window)
    ns:Border(frame, theme.border)
    window = { frame = frame, nav = {}, pageFrames = {} }

    local title = ns:Text(frame, 15)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Crescendo")
    title:SetTextColor(ns:GetAccent())

    local x = 190
    for _, page in ipairs(pages) do
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(90, HEADER - 2)
        button:SetPoint("TOPLEFT", x, 0)
        button.label = ns:Text(button, 13, theme.text, "CENTER")
        button.label:SetPoint("CENTER", 0, 0)
        button.label:SetText(page.title)
        button.underline = button:CreateTexture(nil, "ARTWORK")
        button.underline:SetHeight(2)
        button.underline:SetPoint("BOTTOMLEFT", 12, 0)
        button.underline:SetPoint("BOTTOMRIGHT", -12, 0)
        button.key = page.key
        button:SetScript("OnClick", function() ns:ShowPage(page.key) end)
        button:SetScript("OnEnter", function(self) if self.key ~= UI().page then self.label:SetTextColor(1, 1, 1, 0.8) end end)
        button:SetScript("OnLeave", UpdateNav)
        table.insert(window.nav, button)
        x = x + 94
    end

    local close = ns:Button(frame, "x", 24, 24, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -12)
    window.stopTest = ns:Button(frame, "Stop test", 84, 24, function() ns:StopTest() end, true)
    window.stopTest:SetPoint("RIGHT", close, "LEFT", -8, 0)
    window.testStatus = ns:Text(frame, 11, theme.dim, "RIGHT")
    window.testStatus:SetPoint("RIGHT", window.stopTest, "LEFT", -10, 0)

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 1, -HEADER)
    rule:SetPoint("TOPRIGHT", -1, -HEADER)
    rule:SetColorTexture(1, 1, 1, 0.08)

    window.content = CreateFrame("Frame", nil, frame)
    window.content:SetPoint("TOPLEFT", ns.windowPadding, -HEADER - 12)
    window.content:SetPoint("BOTTOMRIGHT", -ns.windowPadding, ns.windowPadding)
    ns:RefreshTestStatus()
end

function ns:ShowPage(key)
    local page = PageInfo(key) or pages[1]
    UI().page = page.key
    for pageKey, pageFrame in pairs(window.pageFrames) do
        pageFrame:SetShown(pageKey == page.key)
    end
    if not window.pageFrames[page.key] then
        local pageFrame = CreateFrame("Frame", nil, window.content)
        pageFrame:SetAllPoints()
        window.pageFrames[page.key] = pageFrame
        page.build(pageFrame)
    end
    UpdateNav()
    ns:CloseMenu()
    page.refresh()
end

--Opens the window, on a page when one is given, otherwise on the page it was on
function ns:OpenWindow(key)
    if not window then
        CreateWindow()
    end
    local frame = window.frame
    if not frame:IsShown() then
        ns:SelectCurrentBoss()
    end
    local point = UI().windowPoint
    frame:ClearAllPoints()
    if point then
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
    ns:ShowPage(key or UI().page)
    ns:RefreshTestStatus()
end

--In a raid, the planner opens on the boss the player is about to pull, on that difficulty and for their own spec
function ns:SelectCurrentBoss()
    if not ns.db.options.followRaid then
        return
    end
    local boss, difficultyId = ns:CurrentBoss()
    if not boss then
        return
    end
    local ui = UI()
    if ui.boss ~= boss then
        ui.boss, ui.ability, ui.abilityScope = boss, nil, nil
    end
    if ns.difficulties[difficultyId] then
        ui.difficulty = difficultyId
    end
    ui.spec = ns:GetPlayerSpecKey() or ui.spec
    --Unfold the boss's raid
    if ui.foldedRaids then
        ui.foldedRaids[ns.bosses[boss].raid] = false
    end
end

function ns:ToggleWindow(key)
    if window and window.frame:IsShown() and (not key or key == UI().page) then
        window.frame:Hide()
    else
        ns:OpenWindow(key)
    end
end

--Redraws the page that shows, after something changed outside it
function ns:RefreshWindow()
    if window and window.frame:IsShown() then
        PageInfo(UI().page).refresh()
    end
end

--For tests
function ns:GetWindow()
    return window
end

--A page in the game's settings with a button to open the window, so the addon can be found there too
local function AddSettingsEntry()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return
    end
    local panel = CreateFrame("Frame")
    local text = ns:Text(panel, 13)
    text:SetPoint("TOPLEFT", 16, -16)
    text:SetText("Plans, ramps and display settings are in the addon's own window. Type /cres to open it.")
    local open = ns:Button(panel, "Open Crescendo", 200, 28, function()
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        ns:OpenWindow()
    end, true)
    open:SetPoint("TOPLEFT", 16, -44)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Crescendo")
    Settings.RegisterAddOnCategory(category)
end

--The addon's button in the game's addon menu on the minimap
function Crescendo_OnAddonCompartmentClick()
    ns:ToggleWindow()
end

--/cres opens the window, /cres ramps or /cres display a page, /cres unlock moves the reminders, /cres review shows the
--last pull's review, /cres phase 2 starts stage 2 without a boss mod and /cres stop stops a test
function ns:SetUpCommands()
    AddSettingsEntry()
    SLASH_CRESCENDO1 = "/cres"
    SLASH_CRESCENDO2 = "/crescendo"
    SlashCmdList.CRESCENDO = function(message)
        local command = message:match("^%s*(%S*)"):lower()
        local phase = message:match("^%s*phase%s+(%d+%.?%d*)")
        if phase then
            ns:StartPhaseManually(phase)
        elseif command == 'stop' then
            ns:StopTest()
        elseif command == 'review' then
            ns:OpenPullReview()
        elseif command == 'unlock' or command == 'lock' then
            ns:SetUnlocked(command == 'unlock' and not ns:IsUnlocked())
        elseif PageInfo(command) then
            ns:ToggleWindow(command)
        elseif command == 'settings' or command == 'options' then
            ns:ToggleWindow('display')
        else
            ns:ToggleWindow()
        end
    end
end
