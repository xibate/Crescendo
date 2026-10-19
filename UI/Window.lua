local _, ns = ...

--The addon's window (/cres): a side bar on the left with the pages (Plans, Timeline, Ramps, Display, General) and the
--raids and bosses, a header along the top and the page below it. The side bar folds down to icons and a boss button.
--Plans and Timeline share the selected boss, difficulty and spec, the other pages show their name in the header.
--Pages register with ns:RegisterPage and are built the first time they show

local theme = ns.theme
local WIDTH, HEIGHT = 1320, 720
local SIDE_OPEN, SIDE_FOLDED = 210, 52
local HEADER = 50
local ROW_H = 26
local MEDIA = "Interface/Addons/Crescendo/Media/"
ns.windowPadding = 14

local window
local pages = {}

--build(frame) creates the page in its frame, refresh() redraws it from the saved settings. info.icon is the page's
--icon in Media, info.bossBar shows the boss, difficulty and spec in the header
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
    for _, list in ipairs({ window.nav, window.navIcons }) do
        for _, button in ipairs(list) do
            local active = button.key == UI().page
            local alpha = active and 1 or (button.hover and 0.85 or 0.5)
            if button.label then
                button.label:SetTextColor(1, 1, 1, alpha)
            end
            button.icon:SetVertexColor(1, 1, 1, alpha)
            button.bar:SetColorTexture(r, g, b, active and 1 or 0)
            button.background:SetColorTexture(1, 1, 1, active and 0.05 or (button.hover and 0.03 or 0))
        end
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

------------------------------------------------------------------------------------------------------------------------
-- The selected boss
------------------------------------------------------------------------------------------------------------------------

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
    ns:CloseMenu()
    ns:RefreshWindow()
end

--Raids are folded and unfolded by clicking their name. A raid starts folded when Config/Bosses.lua says so
local function RaidFolded(raid)
    local ui = UI()
    ui.foldedRaids = ui.foldedRaids or {}
    if ui.foldedRaids[raid.name] == nil then
        ui.foldedRaids[raid.name] = raid.collapsed == true
    end
    return ui.foldedRaids[raid.name]
end

--How many lines the plan of a boss has, for the selected spec and difficulty
local function PlanCount(encounterId)
    local plan = ns:ParsePlan(ns:GetPlan(ns:SelectedSpec(), ns.difficulties[UI().difficulty].slug, encounterId))
    return #plan.times + #plan.abilities
end

------------------------------------------------------------------------------------------------------------------------
-- The side bar
------------------------------------------------------------------------------------------------------------------------

local function Edge(frame)
    local edge = frame:CreateTexture(nil, "BORDER")
    edge:SetWidth(1)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetColorTexture(1, 1, 1, 0.08)
end

local function PageButton(parent, page, folded)
    local button = CreateFrame("Button", nil, parent)
    button.background = ns:Fill(button, { 1, 1, 1, 0 })
    button.bar = button:CreateTexture(nil, "ARTWORK")
    button.bar:SetWidth(2)
    button.bar:SetPoint("TOPLEFT")
    button.bar:SetPoint("BOTTOMLEFT")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(MEDIA .. (page.icon or "rail-plans"))
    if folded then
        button:SetSize(SIDE_FOLDED, 40)
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("CENTER")
        ns:Tooltip(button, page.title)
    else
        button:SetHeight(30)
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("LEFT", 14, 0)
        button.label = ns:Text(button, 12)
        button.label:SetPoint("LEFT", button.icon, "RIGHT", 10, 0)
        button.label:SetText(page.title)
    end
    button.key = page.key
    button:SetScript("OnClick", function() ns:ShowPage(page.key) end)
    button:HookScript("OnEnter", function(self) self.hover = true UpdateNav() end)
    button:HookScript("OnLeave", function(self) self.hover = false UpdateNav() end)
    return button
end

--The open side bar: the pages, then the raids with their bosses and how many plan lines each has
local function BuildOpenSide(frame)
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", 1, -1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE_OPEN)
    ns:Fill(side, { 0, 0, 0, 0.25 })
    Edge(side)
    local logo = side:CreateTexture(nil, "ARTWORK")
    logo:SetSize(24, 24)
    logo:SetPoint("TOPLEFT", 12, -12)
    logo:SetTexture(MEDIA .. "logo")
    local name = ns:Text(side, 14)
    name:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    name:SetText("Crescendo")
    name:SetTextColor(ns:GetAccent())
    window.fold = ns:Button(side, "<<", 24, 24, function() ns:SetSideFolded(true) end)
    window.fold:SetPoint("TOPRIGHT", -8, -12)
    ns:Tooltip(window.fold, "Fold the side bar", "Leaves the page icons and a boss button, for more room.")
    local y = -48
    for _, page in ipairs(pages) do
        local button = PageButton(side, page, false)
        button:SetPoint("TOPLEFT", 1, y)
        button:SetPoint("RIGHT", side, "RIGHT", -1, 0)
        table.insert(window.nav, button)
        y = y - 30
    end
    local rule = side:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, y - 8)
    rule:SetPoint("TOPRIGHT", -1, y - 8)
    rule:SetColorTexture(1, 1, 1, 0.08)

    local list = ns:ScrollList(side)
    list:SetPoint("TOPLEFT", 1, y - 14)
    list:SetPoint("BOTTOMRIGHT", -2, 4)
    window.bossList = list
    window.raidHeaders, window.bossRows = {}, {}
    for index, raid in ipairs(ns.raids) do
        local header = ns:FoldHeader(list.content, 24)
        header.label:SetText(raid.name:upper())
        header.raid = raid
        header:SetScript("OnClick", function()
            UI().foldedRaids[raid.name] = not header.folded
            ns:RefreshBossBar()
        end)
        window.raidHeaders[index] = header
        for _, boss in ipairs(raid.bosses) do
            local row = ns:ListRow(list.content, ROW_H)
            row.label:SetPoint("LEFT", 22, 0)
            row.label:SetPoint("RIGHT", -30, 0)
            row.label:SetText(boss.name)
            row.badge = ns:Text(row, 11, theme.text, "RIGHT")
            row.badge:SetPoint("RIGHT", -10, 0)
            row.encounterId = boss.encounterId
            row:SetScript("OnClick", function() SelectBoss(boss.encounterId) end)
            window.bossRows[boss.encounterId] = row
        end
    end
    return side
end

--Bosses to pick from when the side bar is folded: the unfolded raids with their bosses, a folded raid unfolds when
--picked
local function BossMenuItems()
    local _, current = Selection()
    local items = {}
    for _, raid in ipairs(ns.raids) do
        if RaidFolded(raid) and raid.name ~= current.raid then
            table.insert(items, { text = "+ " .. raid.name, value = { raid = raid.name } })
        else
            table.insert(items, { text = raid.name, header = true })
            for _, boss in ipairs(raid.bosses) do
                local count = PlanCount(boss.encounterId)
                table.insert(items, { text = boss.name .. (count > 0 and ("  |cff0cd29f" .. count .. "|r") or ""), value = boss.encounterId })
            end
        end
    end
    return items
end

local function OpenBossMenu()
    ns:OpenMenu(window.bossButton, BossMenuItems(), function(value)
        if type(value) == 'table' then
            UI().foldedRaids[value.raid] = false
            OpenBossMenu()
        else
            SelectBoss(value)
        end
    end)
end

--The folded side bar: the logo, the pages as icons and a button with the boss's initial that opens the boss menu
local function BuildFoldedSide(frame)
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", 1, -1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE_FOLDED)
    ns:Fill(side, { 0, 0, 0, 0.25 })
    Edge(side)
    local logo = side:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("TOP", 0, -12)
    logo:SetTexture(MEDIA .. "logo")
    window.unfold = ns:Button(side, ">>", 28, 22, function() ns:SetSideFolded(false) end)
    window.unfold:SetPoint("TOP", 0, -44)
    ns:Tooltip(window.unfold, "Open the side bar", "Shows the page names and the raids with their bosses.")
    local y = -74
    for _, page in ipairs(pages) do
        local button = PageButton(side, page, true)
        button:SetPoint("TOPLEFT", 0, y)
        table.insert(window.navIcons, button)
        y = y - 42
    end
    local rule = side:CreateTexture(nil, "ARTWORK")
    rule:SetSize(28, 1)
    rule:SetPoint("TOP", 0, y - 6)
    rule:SetColorTexture(1, 1, 1, 0.1)
    window.bossButton = ns:Button(side, "", 36, 36, OpenBossMenu, true)
    window.bossButton:SetPoint("TOP", 0, y - 16)
    window.bossButton.label:SetFont(ns:GetFont(), 15, "")
    ns:Tooltip(window.bossButton, function(tooltip)
        local _, boss = Selection()
        tooltip:SetText(boss.name, 1, 1, 1)
        tooltip:AddLine(boss.raid, 0.7, 0.7, 0.7)
        tooltip:AddLine("Click to pick another boss", ns:GetAccent())
    end)
    local label = ns:SectionLabel(side, "Boss")
    label:SetPoint("TOP", window.bossButton, "BOTTOM", 0, -4)
    return side
end

--Shows the open or the folded side bar, with the header and the page next to it
local function LayOut()
    local folded = UI().sideFolded == true
    local width = folded and SIDE_FOLDED or SIDE_OPEN
    window.openSide:SetShown(not folded)
    window.foldedSide:SetShown(folded)
    window.header:ClearAllPoints()
    window.header:SetPoint("TOPLEFT", width + 1, 0)
    window.header:SetPoint("TOPRIGHT", 0, 0)
    window.rule:ClearAllPoints()
    window.rule:SetPoint("TOPLEFT", width + 1, -HEADER)
    window.rule:SetPoint("TOPRIGHT", -1, -HEADER)
    window.content:ClearAllPoints()
    window.content:SetPoint("TOPLEFT", width + 1 + ns.windowPadding, -HEADER - 12)
    window.content:SetPoint("BOTTOMRIGHT", -ns.windowPadding, ns.windowPadding)
end

--The width the pages have, with the side bar open or folded
function ns:WindowContentWidth()
    local folded = UI().sideFolded == true
    return WIDTH - (folded and SIDE_FOLDED or SIDE_OPEN) - 1 - 2 * ns.windowPadding
end

function ns:SetSideFolded(folded)
    UI().sideFolded = folded or nil
    ns:CloseMenu()
    LayOut()
    ns:RefreshWindow()
end

------------------------------------------------------------------------------------------------------------------------
-- The header
------------------------------------------------------------------------------------------------------------------------

--The boss and its raid on the left, difficulty and spec on the right
local function BuildBossBar(header)
    local bar = CreateFrame("Frame", nil, header)
    bar:SetAllPoints()
    bar.bossName = ns:Text(bar, 16)
    bar.bossName:SetPoint("LEFT", 16, 0)
    bar.raidName = ns:Text(bar, 11, theme.dim)
    bar.raidName:SetPoint("LEFT", bar.bossName, "RIGHT", 10, -1)
    bar.spec = ns:Dropdown(bar, 140, 28, function() return ns.specNames[ns:SelectedSpec()] end,
        function() return ns:SpecMenuItems() end, function(specKey)
            UI().spec = specKey
            UI().ability = nil
            ns:RefreshWindow()
        end)
    bar.spec:SetPoint("RIGHT", -44, 0)
    bar.difficulty = ns:Segmented(bar, {
        { text = ns.difficulties[15].name, value = 15 },
        { text = ns.difficulties[16].name, value = 16 }
    }, 112, 28, function() return UI().difficulty end, function(diffId)
        UI().difficulty = diffId
        ns:RefreshWindow()
    end)
    bar.difficulty:SetPoint("RIGHT", bar.spec, "LEFT", -10, 0)
    function bar:Refresh()
        local _, boss = Selection()
        self.bossName:SetText(boss.name)
        self.raidName:SetText(boss.raid)
        self.difficulty:Refresh()
        self.spec:Refresh()
    end
    return bar
end

--The side bar's bosses and the header, after the boss, difficulty or a plan changed
function ns:RefreshBossBar()
    if not window then
        return
    end
    local selected, boss = Selection()
    window.bossBar:Refresh()
    window.bossButton.label:SetText(boss.name:sub(1, 1):upper())
    local list = window.bossList
    local y = 0
    for index, raid in ipairs(ns.raids) do
        local header = window.raidHeaders[index]
        local folded = RaidFolded(raid)
        header:SetFolded(folded)
        header:SetHighlighted(folded and boss.raid == raid.name)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, y)
        header:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
        y = y - 24
        for _, raidBoss in ipairs(raid.bosses) do
            local row = window.bossRows[raidBoss.encounterId]
            row:SetSelected(raidBoss.encounterId == selected)
            row:SetShown(not folded)
            if not folded then
                local count = PlanCount(raidBoss.encounterId)
                row.badge:SetText(count > 0 and tostring(count) or '')
                row.badge:SetTextColor(ns:GetAccent())
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, y)
                row:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
                y = y - ROW_H
            end
        end
    end
    list:SetContentHeight(-y)
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
    window = { frame = frame, nav = {}, navIcons = {}, pageFrames = {} }
    window.openSide = BuildOpenSide(frame)
    window.foldedSide = BuildFoldedSide(frame)

    --The header: the boss or the page's name, the test that runs, and the close button
    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(HEADER)
    window.header = header
    window.title = ns:Text(header, 15)
    window.title:SetPoint("LEFT", 16, 0)
    window.bossBar = BuildBossBar(header)
    local close = ns:Button(header, "x", 24, 24, function() frame:Hide() end)
    close:SetPoint("RIGHT", -12, 0)
    window.testStatus = ns:Text(header, 11, theme.dim)
    window.testStatus:SetPoint("LEFT", 380, 0)
    window.testStatus:SetWidth(190)
    window.stopTest = ns:Button(header, "Stop test", 84, 24, function() ns:StopTest() end, true)
    window.stopTest:SetPoint("LEFT", window.testStatus, "RIGHT", 8, 0)

    window.rule = frame:CreateTexture(nil, "ARTWORK")
    window.rule:SetHeight(1)
    window.rule:SetColorTexture(1, 1, 1, 0.08)
    window.content = CreateFrame("Frame", nil, frame)
    LayOut()
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
    window.bossBar:SetShown(page.bossBar == true)
    window.title:SetShown(not page.bossBar)
    window.title:SetText(page.title)
    ns:RefreshBossBar()
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
    --Unfold the boss's raid in the side bar
    ui.foldedRaids = ui.foldedRaids or {}
    ui.foldedRaids[ns.bosses[boss].raid] = false
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
        ns:RefreshBossBar()
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
