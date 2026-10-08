local _, ns = ...

--The planner window (/zrh): pick a spec, difficulty and boss on the left, one of the boss's abilities in the middle, and
--assign ramps or spells to it on the right, for every cast or chosen casts, landing a number of seconds before the
--ability. Assignments are saved as ability lines in the boss's plan, which the Plan text tab shows in full

local theme = ns.theme
local WIDTH, HEIGHT = 900, 560
local HEADER = 44
local LEFT_X, LEFT_W = 14, 196
local MID_X, MID_W = 224, 272
local RIGHT_X = 510
local RIGHT_W = WIDTH - RIGHT_X - 14
local ROW_H = 26
local QUESTION_MARK = 134400

local planner

local function UI()
    return ns.db.ui
end

local function Accent(alpha)
    local r, g, b = ns:GetAccent()
    return r, g, b, alpha or 1
end

------------------------------------------------------------------------------------------------------------------------
-- Selection
------------------------------------------------------------------------------------------------------------------------

local function SortedBossIds()
    local ids = {}
    for encounterId in pairs(ns.bosses) do
        table.insert(ids, encounterId)
    end
    table.sort(ids)
    return ids
end

local function Selected()
    local ui = UI()
    if not ns.specNames[ui.spec or ''] then
        ui.spec = ns:GetPlayerSpecKey() or 'Discipline'
    end
    if not ns.difficulties[ui.difficulty or 0] then
        ui.difficulty = 16
    end
    if not ns.bosses[ui.boss or 0] then
        ui.boss = SortedBossIds()[1]
    end
    return ui.spec, ns.difficulties[ui.difficulty].slug, ui.boss
end

local function GetPlanText()
    local specKey, diffSlug, boss = Selected()
    return ns:GetPlan(specKey, diffSlug, boss)
end

local function SetPlanText(text)
    local specKey, diffSlug, boss = Selected()
    ns:SetPlan(specKey, diffSlug, boss, text)
end

local function SpellNameAndIcon(spell, fallbackName)
    local info = spell and C_Spell.GetSpellInfo(spell)
    return (info and info.name) or fallbackName or tostring(spell), (info and info.iconID) or QUESTION_MARK
end

--The boss's abilities to list: the known ones, then ones a boss mod showed bars for, then ones only named in the plan.
--A boss can have two abilities with the same name, but a seen or planned ability with a listed name is the same one
function ns:GetPlannerAbilities(encounterId, planText)
    local abilities, seenIds, seenNames = {}, {}, {}
    local function Add(ability, matchName)
        if (ability.spellId and seenIds[ability.spellId]) or (matchName and ability.name and seenNames[ability.name:lower()]) then
            return
        end
        if ability.spellId then
            seenIds[ability.spellId] = true
        end
        if ability.name then
            seenNames[ability.name:lower()] = true
        end
        table.insert(abilities, ability)
    end
    for _, ability in ipairs(ns.bossAbilities[encounterId] or {}) do
        Add({ spellId = ability.spellId, name = ability.name, group = ability.group }, false)
    end
    local seen = ns.db.seenAbilities[encounterId] or {}
    local seenList = {}
    for name, spellId in pairs(seen) do
        table.insert(seenList, { spellId = type(spellId) == 'number' and spellId or nil, name = name, group = "Seen in your boss mod" })
    end
    table.sort(seenList, function(a, b) return a.name < b.name end)
    for _, ability in ipairs(seenList) do
        Add(ability, true)
    end
    for _, anchor in ipairs(ns:ParsePlan(planText).abilities) do
        if anchor.spellId then
            Add({ spellId = anchor.spellId, name = (SpellNameAndIcon(anchor.spellId)), group = "Only in the plan" }, true)
        else
            Add({ name = anchor.name, group = "Only in the plan" }, true)
        end
    end
    return abilities
end

local function AbilityKey(ability)
    return ability.spellId and tostring(ability.spellId) or ('name:' .. ability.name:lower())
end

local function SelectedAbility(abilities)
    for _, ability in ipairs(abilities) do
        if AbilityKey(ability) == UI().ability then
            return ability
        end
    end
    local first = abilities[1]
    UI().ability = first and AbilityKey(first)
    return first
end

------------------------------------------------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------------------------------------------------

local function CreateWindow()
    local frame = CreateFrame("Frame", "ZynxRampHelperPlanner", UIParent)
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
        UI().plannerPoint = { point, relativePoint, x, y }
    end)
    frame:SetScript("OnHide", function()
        ns:CloseMenu()
    end)
    table.insert(UISpecialFrames, "ZynxRampHelperPlanner")
    ns:Fill(frame, theme.window)
    ns:Border(frame, theme.border)

    local title = ns:Text(frame, 15)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Zynx Ramp Helper")
    title:SetTextColor(Accent())
    local subtitle = ns:Text(frame, 12, theme.dim)
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
    subtitle:SetText("Planner")

    local close = ns:Button(frame, "x", 24, 24, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -10)
    local settings = ns:Button(frame, "Settings", 84, 24, function()
        frame:Hide()
        ns:OpenSettings()
    end)
    settings:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 1, -HEADER)
    rule:SetPoint("TOPRIGHT", -1, -HEADER)
    rule:SetColorTexture(Accent(0.55))

    planner = { frame = frame }
    return frame
end

local function Column(x, width)
    local column = CreateFrame("Frame", nil, planner.frame)
    column:SetPoint("TOPLEFT", x, -HEADER - 12)
    column:SetPoint("BOTTOMLEFT", x, 14)
    column:SetWidth(width)
    return column
end

------------------------------------------------------------------------------------------------------------------------
-- Left: spec, difficulty and boss
------------------------------------------------------------------------------------------------------------------------

local Refresh

--A selectable list row with an accent bar on the left when selected
local function ListRow(parent, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height or ROW_H)
    row.background = ns:Fill(row, { 1, 1, 1, 0 }, "BACKGROUND")
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetWidth(2)
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.label = ns:Text(row, 12)
    function row:SetSelected(selected)
        self.selected = selected
        if selected then
            self.bar:SetColorTexture(Accent())
            self.bar:Show()
            self.background:SetColorTexture(1, 1, 1, 0.07)
            self.label:SetTextColor(1, 1, 1, 1)
        else
            self.bar:Hide()
            self.background:SetColorTexture(1, 1, 1, 0)
            self.label:SetTextColor(1, 1, 1, 0.7)
        end
    end
    row:SetScript("OnEnter", function(self) if not self.selected then self.background:SetColorTexture(1, 1, 1, 0.04) end end)
    row:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
    return row
end

local function BuildLeft()
    local left = Column(LEFT_X, LEFT_W)
    local specLabel = ns:SectionLabel(left, "Spec")
    specLabel:SetPoint("TOPLEFT", 0, 0)
    local spec = ns:Button(left, "", LEFT_W, 26)
    spec:SetPoint("TOPLEFT", 0, -16)
    spec.label:ClearAllPoints()
    spec.label:SetPoint("LEFT", 10, 0)
    spec.label:SetPoint("RIGHT", -24, 0)
    spec.label:SetJustifyH("LEFT")
    local arrow = ns:Text(spec, 11, theme.dim, "RIGHT")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")
    spec:SetScript("OnClick", function(self)
        local items = {}
        for _, info in pairs(ns.specs) do
            table.insert(items, { text = info.name, value = info.key })
        end
        table.sort(items, function(a, b) return a.text < b.text end)
        ns:OpenMenu(self, items, function(specKey)
            UI().spec = specKey
            UI().ability = nil
            Refresh()
        end)
    end)
    planner.specButton = spec

    local diffLabel = ns:SectionLabel(left, "Difficulty")
    diffLabel:SetPoint("TOPLEFT", 0, -56)
    planner.difficultyButtons = {}
    local x = 0
    for _, diffId in ipairs({ 15, 16 }) do
        local button = ns:Button(left, ns.difficulties[diffId].name, (LEFT_W - 6) / 2, 26, function()
            UI().difficulty = diffId
            Refresh()
        end)
        button:SetPoint("TOPLEFT", x, -72)
        button.diffId = diffId
        planner.difficultyButtons[diffId] = button
        x = x + (LEFT_W - 6) / 2 + 6
    end

    local bossLabel = ns:SectionLabel(left, "Boss")
    bossLabel:SetPoint("TOPLEFT", 0, -112)
    planner.bossRows = {}
    local y = -128
    for _, encounterId in ipairs(SortedBossIds()) do
        local row = ListRow(left)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        row.label:SetPoint("LEFT", 12, 0)
        row.label:SetPoint("RIGHT", -8, 0)
        row.label:SetText(ns.bosses[encounterId].name)
        row.encounterId = encounterId
        row:SetScript("OnClick", function()
            UI().boss = encounterId
            UI().ability = nil
            Refresh()
        end)
        planner.bossRows[encounterId] = row
        y = y - ROW_H
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Middle: the boss's abilities
------------------------------------------------------------------------------------------------------------------------

local function BuildMiddle()
    local middle = Column(MID_X, MID_W)
    ns:Fill(middle, theme.well)
    ns:Border(middle, theme.border)
    local label = ns:SectionLabel(middle, "Boss abilities")
    label:SetPoint("TOPLEFT", 10, -10)
    local hint = ns:Text(middle, 10, theme.section, "RIGHT")
    hint:SetPoint("TOPRIGHT", -10, -10)
    hint:SetText("ASSIGNED")
    local list = ns:ScrollList(middle)
    list:SetPoint("TOPLEFT", 1, -28)
    list:SetPoint("BOTTOMRIGHT", -1, 1)
    planner.abilityList = list
    planner.abilityRows = {}
    planner.groupLabels = {}
end

local function AbilityRow(index)
    local row = planner.abilityRows[index]
    if row then
        return row
    end
    local list = planner.abilityList
    row = ListRow(list.content)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.label:SetPoint("RIGHT", -34, 0)
    row.badge = ns:Text(row, 11, theme.text, "RIGHT")
    row.badge:SetPoint("RIGHT", -12, 0)
    row:SetScript("OnClick", function(self)
        UI().ability = AbilityKey(self.ability)
        Refresh()
    end)
    planner.abilityRows[index] = row
    return row
end

local function GroupLabel(index)
    local label = planner.groupLabels[index]
    if not label then
        label = ns:Text(planner.abilityList.content, 10, theme.section)
        planner.groupLabels[index] = label
    end
    return label
end

local function RefreshAbilities(abilities, selected, planText)
    local list = planner.abilityList
    for _, row in ipairs(planner.abilityRows) do
        row:Hide()
    end
    for _, label in ipairs(planner.groupLabels) do
        label:Hide()
    end
    local y, group, groups = -2, nil, 0
    for index, ability in ipairs(abilities) do
        if ability.group ~= group then
            group = ability.group
            if group then
                groups = groups + 1
                local label = GroupLabel(groups)
                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", 10, y - 8)
                label:SetPoint("RIGHT", list.content, "RIGHT", -10, 0)
                label:SetText(group:upper())
                label:Show()
                y = y - 26
            end
        end
        local row = AbilityRow(index)
        row.ability = ability
        local name, icon = SpellNameAndIcon(ability.spellId, ability.name)
        row.label:SetText(name)
        row.icon:SetTexture(icon)
        local count = #ns:GetAbilityAssignments(planText, ability)
        row.badge:SetText(count > 0 and tostring(count) or '')
        row.badge:SetTextColor(Accent())
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
        row:SetSelected(selected ~= nil and AbilityKey(ability) == AbilityKey(selected))
        row:Show()
        y = y - ROW_H
    end
    list:SetContentHeight(-y + 4)
end

------------------------------------------------------------------------------------------------------------------------
-- Right: assignments of the selected ability, and the plan text
------------------------------------------------------------------------------------------------------------------------

local COLUMNS = { casts = 0, entry = 72, menu = 244, before = 276, delete = 340 }

local function ParseCasts(text)
    local casts = {}
    for number in (text or ''):gmatch('%d+') do
        table.insert(casts, tonumber(number))
    end
    table.sort(casts)
    return #casts > 0 and casts or nil
end

local function SaveAssignments()
    local _, _, boss = Selected()
    if planner.ability then
        SetPlanText(ns:SetAbilityAssignments(GetPlanText(), boss, planner.ability, planner.assignments))
    end
end

local function EntryMenuItems(specKey)
    local items = { { text = "Ramps", header = true } }
    for _, name in ipairs(ns:GetRampNames(specKey)) do
        local ramp = ns:GetRamps(specKey)[name]
        local _, icon = SpellNameAndIcon(ramp.spellId)
        table.insert(items, { text = name, value = name, icon = icon })
    end
    if #items == 1 then
        table.insert(items, { text = "This spec has no ramps", header = true })
    end
    table.insert(items, { text = "Cooldowns", header = true })
    for _, spellId in ipairs(ns.specCooldowns[specKey] or {}) do
        local info = C_Spell.GetSpellInfo(spellId)
        if info and info.name then
            table.insert(items, { text = info.name, value = info.name, icon = info.iconID })
        end
    end
    return items
end

--What an assignment does, in words, or what is wrong with it
local function DescribeAssignment(assignment)
    local specKey = Selected()
    local entry = assignment.entry or ''
    if not entry:find('%S') then
        return "Pick a ramp or spell", false
    end
    local steps = ns:GetEntrySteps(specKey, entry)
    if not steps then
        return "Not a ramp or a spell you know", true
    end
    local first = 0
    for _, step in ipairs(steps) do
        first = math.max(first, step.offset or 0)
    end
    local before = assignment.before or 0
    local casts = assignment.casts and ("cast " .. table.concat(assignment.casts, ', ')) or "every cast"
    local timing = "at"
    if before > 0 then
        timing = string.format("%gs before", before)
    elseif before < 0 then
        timing = string.format("%gs after", -before)
    end
    if first > 0 then
        return string.format("Lands %s %s, first message %gs earlier", timing, casts, math.floor(first * 10 + 0.5) / 10), false
    end
    return string.format("Shows %s %s", timing, casts), false
end

local function AssignmentRow(index)
    local row = planner.assignmentRows[index]
    if row then
        return row
    end
    local parent = planner.assignmentList.content
    row = CreateFrame("Frame", nil, parent)
    row:SetHeight(46)
    row.casts = ns:EditBox(row, 64, 26, function(text)
        row.assignment.casts = ParseCasts(text)
        row.casts:SetValue(row.assignment.casts and table.concat(row.assignment.casts, ',') or '')
        SaveAssignments()
        Refresh(true)
    end)
    row.casts:SetPoint("TOPLEFT", COLUMNS.casts, 0)
    row.entry = ns:EditBox(row, COLUMNS.menu - COLUMNS.entry - 2, 26, function(text)
        row.assignment.entry = text:match('^%s*(.-)%s*$')
        SaveAssignments()
        Refresh(true)
    end)
    row.entry:SetPoint("TOPLEFT", COLUMNS.entry, 0)
    row.menu = ns:Button(row, "v", 26, 26, function(self)
        ns:OpenMenu(row.entry, EntryMenuItems((Selected())), function(value)
            row.assignment.entry = value
            SaveAssignments()
            Refresh(true)
        end)
    end)
    row.menu:SetPoint("TOPLEFT", COLUMNS.menu, 0)
    row.before = ns:EditBox(row, 54, 26, function(text)
        row.assignment.before = tonumber(text) or 0
        SaveAssignments()
        Refresh(true)
    end)
    row.before:SetPoint("TOPLEFT", COLUMNS.before, 0)
    row.delete = ns:Button(row, "x", 26, 26, function()
        table.remove(planner.assignments, row.index)
        SaveAssignments()
        Refresh(true)
    end)
    row.delete:SetPoint("TOPLEFT", COLUMNS.delete, 0)
    row.note = ns:Text(row, 10, theme.dim)
    row.note:SetPoint("TOPLEFT", COLUMNS.entry + 2, -29)
    row.note:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    planner.assignmentRows[index] = row
    return row
end

local function BuildAssignmentsTab(panel)
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetAllPoints()
    planner.assignmentsTab = tab

    planner.abilityIcon = tab:CreateTexture(nil, "ARTWORK")
    planner.abilityIcon:SetSize(30, 30)
    planner.abilityIcon:SetPoint("TOPLEFT", 0, -2)
    planner.abilityIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    planner.abilityName = ns:Text(tab, 15)
    planner.abilityName:SetPoint("TOPLEFT", planner.abilityIcon, "TOPRIGHT", 10, -1)
    planner.abilityName:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.abilityInfo = ns:Text(tab, 10, theme.dim)
    planner.abilityInfo:SetPoint("BOTTOMLEFT", planner.abilityIcon, "BOTTOMRIGHT", 10, 1)

    local headers = { { "Casts", COLUMNS.casts }, { "Ramp or spell", COLUMNS.entry }, { "Sec before", COLUMNS.before } }
    for _, header in ipairs(headers) do
        local label = ns:SectionLabel(tab, header[1])
        label:SetPoint("TOPLEFT", header[2], -48)
    end
    local list = ns:ScrollList(tab)
    list:SetPoint("TOPLEFT", 0, -64)
    list:SetPoint("BOTTOMRIGHT", 0, 104)
    planner.assignmentList = list
    planner.assignmentRows = {}

    planner.addButton = ns:Button(tab, "+ Add assignment", 150, 26, function()
        if planner.ability then
            table.insert(planner.assignments, { before = 0, entry = '' })
            Refresh(true)
        end
    end, true)
    planner.addButton:SetPoint("BOTTOMLEFT", 0, 70)

    planner.empty = ns:Text(tab, 12, theme.dim)
    planner.empty:SetPoint("TOPLEFT", 0, -70)
    planner.empty:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.empty:SetWordWrap(true)

    local help = ns:Text(tab, 10, theme.dim)
    help:SetPoint("BOTTOMLEFT", 0, 0)
    help:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    help:SetHeight(60)
    help:SetJustifyV("BOTTOM")
    help:SetWordWrap(true)
    help:SetText("Casts: leave empty for every cast, or list them like 2,4 using the number in brackets on your boss mod's bar. " ..
        "Sec before: the ramp's last step lands this many seconds before the ability, its earlier steps show before that. " ..
        "Abilities follow the bars of BigWigs or DBM, so the bar has to be enabled there.")
end

local function BuildPlanTextTab(panel)
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetAllPoints()
    planner.planTextTab = tab
    local well = CreateFrame("Frame", nil, tab)
    well:SetPoint("TOPLEFT", 0, 0)
    well:SetPoint("BOTTOMRIGHT", 0, 64)
    ns:Fill(well, theme.input)
    ns:Border(well, theme.borderStrong)
    local scroll = ns:ScrollList(well)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFont(ns:GetFont(), 12, "")
    box:SetTextColor(1, 1, 1, 0.9)
    box:SetWidth(RIGHT_W - 20)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            planner.planStatus:SetText("Not saved yet")
            planner.planStatus:SetTextColor(1, 1, 1, 0.53)
        end
    end)
    scroll:SetScrollChild(box)
    planner.planBox = box
    well:EnableMouse(true)
    well:SetScript("OnMouseDown", function() box:SetFocus() end)

    planner.planSave = ns:Button(tab, "Save", 90, 26, function()
        local text = box:GetText()
        local result = ns:CheckPlan(text)
        if result == true then
            SetPlanText(text)
            Refresh()
            planner.planStatus:SetText("Saved")
            planner.planStatus:SetTextColor(Accent())
        else
            planner.planStatus:SetText(result)
            planner.planStatus:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
        end
    end, true)
    planner.planSave:SetPoint("BOTTOMLEFT", 0, 28)
    planner.planStatus = ns:Text(tab, 11, theme.dim)
    planner.planStatus:SetPoint("LEFT", planner.planSave, "RIGHT", 10, 0)
    planner.planStatus:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    local help = ns:Text(tab, 10, theme.dim)
    help:SetPoint("BOTTOMLEFT", 0, 0)
    help:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    help:SetText("Times after the pull (01:25 - Evangelism), after a stage (00:50 p2 - Rewind) and boss abilities (@...).")
end

local function BuildRight()
    local right = Column(RIGHT_X, RIGHT_W)
    planner.tabButtons = {}
    local tabs = { { key = 'assignments', text = "Assignments" }, { key = 'plan', text = "Plan text" } }
    local x = 0
    for _, info in ipairs(tabs) do
        local button = CreateFrame("Button", nil, right)
        button:SetSize(110, 24)
        button:SetPoint("TOPLEFT", x, 0)
        button.label = ns:Text(button, 12, theme.text, "LEFT")
        button.label:SetPoint("LEFT", 0, 2)
        button.label:SetText(info.text)
        button.underline = button:CreateTexture(nil, "ARTWORK")
        button.underline:SetHeight(2)
        button.underline:SetPoint("BOTTOMLEFT")
        button.underline:SetWidth(button.label:GetStringWidth() or 80)
        button:SetScript("OnClick", function()
            UI().plannerTab = info.key
            Refresh()
        end)
        button.key = info.key
        planner.tabButtons[info.key] = button
        x = x + 120
    end
    local panel = CreateFrame("Frame", nil, right)
    panel:SetPoint("TOPLEFT", 0, -36)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    BuildAssignmentsTab(panel)
    BuildPlanTextTab(panel)
end

local function RefreshAssignments(ability, keepRows)
    local sameAbility = planner.ability and ability and AbilityKey(planner.ability) == AbilityKey(ability)
    if not keepRows or not sameAbility then
        planner.assignments = ability and ns:GetAbilityAssignments(GetPlanText(), ability) or {}
    end
    planner.ability = ability
    for _, row in ipairs(planner.assignmentRows) do
        row:Hide()
    end
    if not ability then
        planner.abilityName:SetText("No boss abilities")
        planner.abilityInfo:SetText("")
        planner.abilityIcon:SetTexture(QUESTION_MARK)
        planner.empty:SetText("This boss has no abilities listed yet. Pull it with BigWigs or DBM and the abilities they show bars for appear here.")
        planner.empty:Show()
        planner.addButton:Hide()
        return
    end
    local name, icon = SpellNameAndIcon(ability.spellId, ability.name)
    planner.abilityName:SetText(name)
    planner.abilityIcon:SetTexture(icon)
    planner.abilityInfo:SetText(ability.spellId and ("Spell id " .. ability.spellId) or "Matched by name")
    planner.addButton:Show()
    if #planner.assignments == 0 then
        planner.empty:SetText("Nothing assigned to " .. name .. " yet. Add a ramp or cooldown to land before it.")
        planner.empty:Show()
    else
        planner.empty:Hide()
    end
    local y = 0
    for index, assignment in ipairs(planner.assignments) do
        local row = AssignmentRow(index)
        row.index = index
        row.assignment = assignment
        row.casts:SetValue(assignment.casts and table.concat(assignment.casts, ',') or '')
        row.entry:SetValue(assignment.entry or '')
        row.before:SetValue(tostring(assignment.before or 0))
        local text, isError = DescribeAssignment(assignment)
        row.note:SetText(text)
        if isError then
            row.note:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
            row.entry.setBorder(theme.error[1], theme.error[2], theme.error[3], 0.8)
        else
            row.note:SetTextColor(1, 1, 1, 0.53)
            row.entry.setBorder(1, 1, 1, 0.22)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", planner.assignmentList.content, "RIGHT", 0, 0)
        row:Show()
        y = y - 50
    end
    planner.assignmentList:SetContentHeight(-y)
end

--Redraws the window from the saved settings. keepRows keeps the assignment rows of the ability as they are, so rows
--that have no ramp or spell yet stay
function Refresh(keepRows)
    if not planner then
        return
    end
    local specKey, diffSlug, boss = Selected()
    local planText = GetPlanText()
    planner.specButton.label:SetText(ns.specNames[specKey])
    for diffId, button in pairs(planner.difficultyButtons) do
        local selected = diffId == UI().difficulty
        button.label:SetTextColor(1, 1, 1, selected and 1 or 0.55)
        if selected then
            button.label:SetTextColor(Accent())
        end
    end
    for encounterId, row in pairs(planner.bossRows) do
        row:SetSelected(encounterId == boss)
    end

    local abilities = ns:GetPlannerAbilities(boss, planText)
    local selected = SelectedAbility(abilities)
    RefreshAbilities(abilities, selected, planText)

    local tab = UI().plannerTab == 'plan' and 'plan' or 'assignments'
    for key, button in pairs(planner.tabButtons) do
        local active = key == tab
        button.label:SetTextColor(1, 1, 1, active and 1 or 0.5)
        button.underline:SetColorTexture(Accent(active and 1 or 0))
    end
    if tab == 'plan' then
        planner.assignmentsTab:Hide()
        planner.planTextTab:Show()
        if not planner.planBox:HasFocus() then
            planner.planBox:SetText(planText)
            planner.planStatus:SetText(ns.specNames[specKey] .. ", " .. ns.difficulties[UI().difficulty].name .. " " .. ns.bosses[boss].name)
            planner.planStatus:SetTextColor(1, 1, 1, 0.53)
        end
    else
        planner.planTextTab:Hide()
        planner.assignmentsTab:Show()
        RefreshAssignments(selected, keepRows)
    end
end

function ns:RefreshPlanner()
    Refresh()
end

function ns:OpenPlanner()
    if not planner then
        CreateWindow()
        BuildLeft()
        BuildMiddle()
        BuildRight()
    end
    local frame = planner.frame
    local point = UI().plannerPoint
    frame:ClearAllPoints()
    if point then
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
    Refresh()
end

function ns:TogglePlanner()
    if planner and planner.frame:IsShown() then
        planner.frame:Hide()
    else
        ns:OpenPlanner()
    end
end

--For tests
function ns:GetPlannerWidgets()
    return planner
end
