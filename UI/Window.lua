local _, ns = ...

--The addon's window (/cres): a rail on the left with the pages (Plans, Timeline, Ramps, Display, General), a header
--bar along the top and the page below it. Plans and Timeline share the header's raid, boss, difficulty and spec, the
--other pages show their name there. Pages register with ns:RegisterPage and are built the first time they show

local theme = ns.theme
local WIDTH, HEIGHT = 1024, 680
local RAIL = 64
local HEADER = 50
ns.windowPadding = 14

local window
local pages = {}

--build(frame) creates the page in its frame, refresh() redraws it from the saved settings. info.icon is the rail's icon
--in Media, info.bossBar shows the raid, boss, difficulty and spec in the header
function ns:RegisterPage(key, title, order, build, refresh, info)
    info = info or {}
    table.insert(pages, { key = key, title = title, order = order, build = build, refresh = refresh, icon = info.icon,
        bossBar = info.bossBar })
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
        local alpha = active and 1 or (button.hover and 0.85 or 0.5)
        button.label:SetTextColor(1, 1, 1, alpha)
        button.icon:SetVertexColor(1, 1, 1, alpha)
        button.bar:SetColorTexture(r, g, b, active and 1 or 0)
        button.background:SetColorTexture(1, 1, 1, active and 0.05 or (button.hover and 0.03 or 0))
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

--The header bar of Plans and Timeline: Raid / Boss, difficulty and spec
local function Selection()
    local ui = UI()
    if not ns.bosses[ui.boss or 0] then
        ui.boss = ns.raids[1].bosses[1].encounterId
    end
    if not ns.difficulties[ui.difficulty or 0] then
        ui.difficulty = 16
    end
    return ui.boss, ns.bosses[ui.boss]
end

local function SelectBoss(encounterId)
    local ui = UI()
    if ui.boss ~= encounterId then
        ui.boss, ui.ability, ui.abilityScope, ui.timelineCast = encounterId, nil, nil, nil
    end
    ns:RefreshWindow()
end

local function BuildBossBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(HEADER)
    bar.raid = ns:Dropdown(bar, 160, 28, function() return select(2, Selection()).raid end, function()
        local items = { { text = "Raids", header = true } }
        for _, raid in ipairs(ns.raids) do
            table.insert(items, { text = raid.name, value = raid.name })
        end
        return items
    end, function(raidName)
        for _, raid in ipairs(ns.raids) do
            if raid.name == raidName and ns.bosses[UI().boss].raid ~= raidName then
                SelectBoss(raid.bosses[1].encounterId)
            end
        end
    end, 'plain')
    bar.raid:SetPoint("LEFT", 0, 0)
    bar.raid.label:SetTextColor(1, 1, 1, 0.6)
    local slash = ns:Text(bar, 13, theme.section)
    slash:SetPoint("LEFT", bar.raid, "RIGHT", 4, 0)
    slash:SetText("/")
    bar.boss = ns:Dropdown(bar, 170, 30, function() return select(2, Selection()).name end, function()
        local _, boss = Selection()
        local items = {}
        for _, raid in ipairs(ns.raids) do
            if raid.name == boss.raid then
                table.insert(items, { text = raid.name, header = true })
                for _, raidBoss in ipairs(raid.bosses) do
                    table.insert(items, { text = raidBoss.name, value = raidBoss.encounterId })
                end
            end
        end
        return items
    end, SelectBoss)
    bar.boss:SetPoint("LEFT", slash, "RIGHT", 8, 0)
    bar.boss.label:SetFont(ns:GetFont(), 13, "")
    bar.difficulty = ns:Segmented(bar, {
        { text = ns.difficulties[15].name, value = 15 },
        { text = ns.difficulties[16].name, value = 16 }
    }, 112, 28, function() return UI().difficulty end, function(diffId)
        UI().difficulty = diffId
        ns:RefreshWindow()
    end)
    bar.difficulty:SetPoint("LEFT", bar.boss, "RIGHT", 10, 0)
    bar.spec = ns:Dropdown(bar, 140, 28, function() return ns.specNames[ns:SelectedSpec()] end,
        function() return ns:SpecMenuItems() end, function(specKey)
            UI().spec = specKey
            UI().ability = nil
            ns:RefreshWindow()
        end)
    bar.spec:SetPoint("LEFT", bar.difficulty, "RIGHT", 10, 0)
    function bar:Refresh()
        Selection()
        self.raid:Refresh()
        self.boss:Refresh()
        self.difficulty:Refresh()
        self.spec:Refresh()
    end
    return bar
end

local function NavButton(parent, page, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(RAIL, 56)
    button:SetPoint("TOPLEFT", 0, y)
    button.background = ns:Fill(button, { 1, 1, 1, 0 })
    button.bar = button:CreateTexture(nil, "ARTWORK")
    button.bar:SetWidth(2)
    button.bar:SetPoint("TOPLEFT")
    button.bar:SetPoint("BOTTOMLEFT")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(22, 22)
    button.icon:SetPoint("TOP", 0, -9)
    button.icon:SetTexture("Interface/Addons/Crescendo/Media/" .. (page.icon or "rail-plans"))
    button.label = ns:Text(button, 10, theme.text, "CENTER")
    button.label:SetPoint("BOTTOM", 0, 8)
    button.label:SetText(page.title)
    button.key = page.key
    button:SetScript("OnClick", function() ns:ShowPage(page.key) end)
    button:SetScript("OnEnter", function(self) self.hover = true UpdateNav() end)
    button:SetScript("OnLeave", function(self) self.hover = false UpdateNav() end)
    return button
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

    --The rail: the logo and a button per page
    local rail = CreateFrame("Frame", nil, frame)
    rail:SetPoint("TOPLEFT", 1, -1)
    rail:SetPoint("BOTTOMLEFT", 1, 1)
    rail:SetWidth(RAIL)
    ns:Fill(rail, { 0, 0, 0, 0.25 })
    local edge = rail:CreateTexture(nil, "BORDER")
    edge:SetWidth(1)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetColorTexture(1, 1, 1, 0.08)
    local logo = rail:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOP", 0, -12)
    logo:SetTexture("Interface/Addons/Crescendo/Media/logo")
    window.rail = rail
    local y = -54
    for _, page in ipairs(pages) do
        table.insert(window.nav, NavButton(rail, page, y))
        y = y - 58
    end

    --The header: the boss bar or the page's name, and on the right the test that runs and the close button
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", RAIL + 1, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER)
    window.header = header
    window.title = ns:Text(header, 15)
    window.title:SetPoint("LEFT", 16, 0)
    window.bossBar = BuildBossBar(header)
    window.bossBar:SetPoint("LEFT", 10, 0)
    window.bossBar:SetPoint("RIGHT", header, "RIGHT", -300, 0)

    local close = ns:Button(header, "x", 24, 24, function() frame:Hide() end)
    close:SetPoint("RIGHT", -12, 0)
    window.stopTest = ns:Button(header, "Stop test", 84, 24, function() ns:StopTest() end, true)
    window.stopTest:SetPoint("RIGHT", close, "LEFT", -8, 0)
    window.testStatus = ns:Text(header, 11, theme.dim, "RIGHT")
    window.testStatus:SetPoint("RIGHT", window.stopTest, "LEFT", -10, 0)
    window.testStatus:SetWidth(180)

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", RAIL + 1, -HEADER)
    rule:SetPoint("TOPRIGHT", -1, -HEADER)
    rule:SetColorTexture(1, 1, 1, 0.08)

    window.content = CreateFrame("Frame", nil, frame)
    window.content:SetPoint("TOPLEFT", RAIL + 1 + ns.windowPadding, -HEADER - 12)
    window.content:SetPoint("BOTTOMRIGHT", -ns.windowPadding, ns.windowPadding)
    ns:RefreshTestStatus()
end

--The header bar's raid, boss, difficulty and spec, after they changed somewhere else
function ns:RefreshBossBar()
    if window then
        window.bossBar:Refresh()
    end
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
    window.bossBar:SetShown(page.bossBar == true)
    window.title:SetShown(not page.bossBar)
    window.title:SetText(page.title)
    if page.bossBar then
        window.bossBar:Refresh()
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
        ui.boss, ui.ability, ui.abilityScope, ui.timelineCast = boss, nil, nil, nil
    end
    if ns.difficulties[difficultyId] then
        ui.difficulty = difficultyId
    end
    ui.spec = ns:GetPlayerSpecKey() or ui.spec
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
        local page = PageInfo(UI().page)
        if page.bossBar then
            window.bossBar:Refresh()
        end
        page.refresh()
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

--/cres opens the window, /cres timeline, /cres ramps or /cres display a page, /cres unlock moves the reminders, /cres review shows the
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
