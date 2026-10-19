local _, ns = ...

--The Timeline page: the recorded pull of the selected boss as a chart. Every ability has a lane with its casts,
--numbered like the boss mod counts them, the stages are bands behind them and the bottom lane shows when each of your
--assignments lands, red when the spell won't be ready. Click a cast to see what is assigned to it and to assign
--something: to that cast only, every cast in its stage or every cast in every stage

local theme = ns.theme
local kit
local NAME_W = 150
local TOOLBAR_H = 36
local RULER_H = 26
local STAGE_H = 26
local LANE_H = 28
local YOU_H = 34
local PANEL_H = 214
local LEFT_W = 240
local RIGHT_W = 260
local DIAMOND = "Interface/Addons/Crescendo/Media/diamond"

local page

local function UI()
    return ns.db.ui
end

local function Accent(alpha)
    local r, g, b = ns:GetAccent()
    return r, g, b, alpha or 1
end

local function ErrorColor(alpha)
    return theme.error[1], theme.error[2], theme.error[3], alpha or 1
end

local Refresh

------------------------------------------------------------------------------------------------------------------------
-- What is shown: lanes of casts and the selected cast
------------------------------------------------------------------------------------------------------------------------

--The stages of the pull from its start, also when the boss mod didn't report the first one
local function Stages(timeline)
    local stages = {}
    if not timeline.stages[1] or timeline.stages[1].at > 0.5 then
        table.insert(stages, { at = 0, stage = '1' })
    end
    for _, stage in ipairs(timeline.stages) do
        table.insert(stages, stage)
    end
    return stages
end

--The lanes: one per ability that went off, in the order of the ability list, with its casts by time. Each lane has
--the ability as the Plans page knows it
local function Lanes(timeline, boss, planText)
    local abilities = ns:GetPlannerAbilities(boss, planText, UI().difficulty == 15)
    local lanes, byKey = {}, {}
    for _, cast in ipairs(timeline.casts) do
        local ability, order
        for index, known in ipairs(abilities) do
            if (cast.spellId and known.spellId == cast.spellId) or (known.name and cast.name and known.name:lower() == cast.name:lower()) then
                ability, order = known, index
                break
            end
        end
        ability = ability or { spellId = cast.spellId, name = cast.name }
        local key = kit.AbilityKey(ability)
        local lane = byKey[key]
        if not lane then
            lane = { key = key, ability = ability, order = order or (1000 + #lanes), casts = {} }
            byKey[key] = lane
            table.insert(lanes, lane)
        end
        table.insert(lane.casts, cast)
        cast.lane = lane
    end
    table.sort(lanes, function(a, b) return a.order < b.order end)
    if UI().timelineAssigned then
        local assigned = {}
        for _, lane in ipairs(lanes) do
            for _, cast in ipairs(lane.casts) do
                if cast.assigned then
                    table.insert(assigned, lane)
                    break
                end
            end
        end
        lanes = assigned
    end
    return lanes
end

--True when an assignment triggers on a cast with this number
local function Covers(assignment, count)
    if assignment.casts and #assignment.casts > 0 then
        for _, number in ipairs(assignment.casts) do
            if number == count then
                return true
            end
        end
        return false
    end
    if assignment.every then
        local from = assignment.from or 1
        return count ~= nil and count >= from and (count - from) % assignment.every == 0
    end
    return true
end

local function CastTitle(cast)
    local name = kit.SpellNameAndIcon(cast.spellId, cast.name)
    return name .. (cast.count and (" · cast " .. cast.count) or "")
end

--What the selected cast is assigned with: for its stage, and for every stage
local function ScopeMode(boss, cast)
    local mode = UI().timelineScope
    if mode ~= 'cast' and mode ~= 'stage' and mode ~= 'all' then
        mode = 'cast'
    end
    if not kit.HasStages(boss) and mode == 'stage' then
        mode = 'all'
    end
    if mode == 'cast' and not (cast and cast.count) then
        mode = kit.HasStages(boss) and 'stage' or 'all'
    end
    return mode
end

------------------------------------------------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------------------------------------------------

--The width of the lanes' tracks, from the window's layout so it is right straight after the side bar folds
local function TrackWidth()
    return ns:WindowContentWidth() - NAME_W - 16
end

--Where a time is on the lanes, from the left of the chart
local function X(at)
    return NAME_W + math.max(0, math.min(1, at / page.duration)) * TrackWidth()
end

local function BuildToolbar(frame)
    page.info = ns:Text(frame, 11, theme.dim)
    page.info:SetPoint("TOPLEFT", 0, -8)
    page.info:SetPoint("RIGHT", frame, "RIGHT", -330, 0)
    page.onlyAssigned = ns:Checkbox(frame, "Only assigned abilities", function() return UI().timelineAssigned end, function(value)
        UI().timelineAssigned = value or nil
        Refresh()
    end)
    page.onlyAssigned:SetWidth(170)
    page.onlyAssigned:SetPoint("TOPRIGHT", -140, -4)
    page.replay = ns:Button(frame, "Replay pull", 128, 26, function()
        if ns:IsTesting() then
            ns:StopTest()
            return
        end
        local specKey, diffSlug, boss = kit.Selected()
        local from = page.cursor
        page.cursor = nil
        ns:StartTest(specKey, diffSlug, boss, nil, from)
    end, true)
    page.replay:SetPoint("TOPRIGHT", 0, 0)
    ns:Tooltip(page.replay, "Replay pull", "Runs the recorded pull again with your plan, so its reminders show and speak as they " ..
        "would in the raid. Nothing has to be pulled, it works anywhere. It starts where the line on the time bar is, when " ..
        "you dragged it there.")
end

local function BuildChart(frame)
    local chart = CreateFrame("Frame", nil, frame)
    chart:SetPoint("TOPLEFT", 0, -TOOLBAR_H)
    chart:SetPoint("BOTTOMRIGHT", 0, PANEL_H + 12)
    ns:Fill(chart, theme.well)
    ns:Border(chart, theme.border)
    page.chart = chart
    page.bands, page.edges, page.stageLabels, page.stageBoxes = {}, {}, {}, {}
    page.minorTicks, page.majorTicks, page.tickLabels = {}, {}, {}

    --The time bar: a tick every 10 seconds, a longer one with the time every 30
    page.ticksRow = CreateFrame("Frame", nil, chart)
    page.ticksRow:SetPoint("TOPLEFT", 0, 0)
    page.ticksRow:SetPoint("TOPRIGHT", 0, 0)
    page.ticksRow:SetHeight(RULER_H)
    ns:Fill(page.ticksRow, { 1, 1, 1, 0.02 })
    local timeName = ns:SectionLabel(page.ticksRow, "Time")
    timeName:SetPoint("LEFT", 10, 0)
    page.ticksRow:EnableMouse(true)
    page.ticksRow:SetScript("OnMouseDown", function() page.StartDrag() end)
    page.ticksRow:SetScript("OnMouseUp", function() page.StopDrag() end)
    ns:Tooltip(page.ticksRow, "Time bar", "Drag along it to move the line through the pull: Next up follows it, and Replay pull " ..
        "starts there. While a replay runs, the replay jumps to where you let go.")
    local ruleTime = page.ticksRow:CreateTexture(nil, "ARTWORK")
    ruleTime:SetHeight(1)
    ruleTime:SetPoint("BOTTOMLEFT")
    ruleTime:SetPoint("BOTTOMRIGHT")
    ruleTime:SetColorTexture(1, 1, 1, 0.1)
    page.stageRow = CreateFrame("Frame", nil, chart)
    page.stageRow:SetPoint("TOPLEFT", 0, -RULER_H)
    page.stageRow:SetPoint("TOPRIGHT", 0, -RULER_H)
    page.stageRow:SetHeight(STAGE_H)
    local stageName = ns:SectionLabel(page.stageRow, "Stage")
    stageName:SetPoint("LEFT", 10, 0)
    local rule = page.stageRow:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetColorTexture(1, 1, 1, 0.06)

    page.lanesList = ns:ScrollList(chart)
    page.lanesList:SetPoint("TOPLEFT", 0, -RULER_H - STAGE_H)
    page.lanesList:SetPoint("BOTTOMRIGHT", 0, YOU_H)
    page.lanes, page.markers = {}, {}

    page.you = CreateFrame("Frame", nil, chart)
    page.you:SetPoint("BOTTOMLEFT", 1, 1)
    page.you:SetPoint("BOTTOMRIGHT", -1, 1)
    page.you:SetHeight(YOU_H)
    page.youFill = ns:Fill(page.you, { 1, 1, 1, 0 })
    page.youEdge = page.you:CreateTexture(nil, "ARTWORK")
    page.youEdge:SetHeight(1)
    page.youEdge:SetPoint("TOPLEFT")
    page.youEdge:SetPoint("TOPRIGHT")
    page.youLabel = ns:Text(page.you, 12)
    page.youLabel:SetPoint("LEFT", 10, 0)
    page.youLabel:SetText("You")
    page.diamonds = {}

    --The replay's position, over everything
    page.overlay = CreateFrame("Frame", nil, chart)
    page.overlay:SetAllPoints()
    page.overlay:SetFrameLevel((chart:GetFrameLevel() or 1) + 20)
    page.glow = page.overlay:CreateTexture(nil, "ARTWORK")
    page.glow:SetWidth(8)
    page.glow:Hide()
    page.playhead = page.overlay:CreateTexture(nil, "OVERLAY")
    page.playhead:SetWidth(2)
    page.playhead:Hide()
    page.bubble = CreateFrame("Frame", nil, page.overlay)
    page.bubble:SetSize(40, 16)
    page.bubble.fill = ns:Fill(page.bubble, { 1, 1, 1, 1 })
    page.bubble.text = page.bubble:CreateFontString(nil, "OVERLAY")
    page.bubble.text:SetFont(ns:GetFont(), 10, "")
    page.bubble.text:SetTextColor(0.03, 0.07, 0.05, 1)
    page.bubble.text:SetPoint("CENTER")
    page.bubble:Hide()

    page.empty = ns:Text(frame, 13, theme.dim)
    page.empty:SetPoint("TOPLEFT", 0, -TOOLBAR_H - 16)
    page.empty:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    page.empty:SetWordWrap(true)
    page.empty:SetJustifyV("TOP")
    page.empty:SetHeight(120)
end

local function SelectCast(cast)
    local _, _, boss = kit.Selected()
    page.cursor = nil
    UI().timelineCast = { key = cast.lane.key, at = cast.at }
    --The Plans page shows the same ability, on the cast's stage
    kit.SelectAbility(cast.lane.ability, kit.HasStages(boss) and cast.stage or 'all')
    kit.ResetCards(page.cardList)
    Refresh()
end

local function Lane(index)
    local lane = page.lanes[index]
    if lane then
        return lane
    end
    lane = CreateFrame("Frame", nil, page.lanesList.content)
    lane:SetHeight(LANE_H)
    lane.background = ns:Fill(lane, { 1, 1, 1, 0 })
    lane.icon = lane:CreateTexture(nil, "ARTWORK")
    lane.icon:SetSize(16, 16)
    lane.icon:SetPoint("LEFT", 10, 0)
    lane.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    lane.label = ns:Text(lane, 11)
    lane.label:SetPoint("LEFT", lane.icon, "RIGHT", 7, 0)
    lane.label:SetWidth(NAME_W - 40)
    --The ability's name: the same tooltip as in the Plans page's list, and a click selects its first cast
    lane.name = CreateFrame("Button", nil, lane)
    lane.name:SetPoint("TOPLEFT")
    lane.name:SetPoint("BOTTOMLEFT")
    lane.name:SetWidth(NAME_W - 6)
    lane.name:SetScript("OnEnter", function() lane.label:SetTextColor(1, 1, 1, 1) end)
    lane.name:SetScript("OnLeave", function() lane.label:SetTextColor(1, 1, 1, lane.selected and 1 or 0.75) end)
    lane.name:SetScript("OnClick", function()
        if lane.info and lane.info.casts[1] then
            SelectCast(lane.info.casts[1])
        end
    end)
    ns:Tooltip(lane.name, function(tooltip)
        if not lane.info then
            return false
        end
        kit.AbilityTooltip(tooltip, { ability = lane.info.ability })
    end)
    local rule = lane:CreateTexture(nil, "BORDER")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetColorTexture(1, 1, 1, 0.04)
    page.lanes[index] = lane
    return lane
end

--A cast on its lane: the ability's icon with its number, framed in the accent colour when something is assigned to it
local function Marker(index)
    local marker = page.markers[index]
    if marker then
        return marker
    end
    marker = CreateFrame("Button", nil, page.lanesList.content)
    marker:SetSize(18, 18)
    marker:SetFrameLevel((page.lanesList.content:GetFrameLevel() or 1) + 5)
    marker.icon = marker:CreateTexture(nil, "ARTWORK")
    marker.icon:SetAllPoints()
    marker.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    marker.shade = marker:CreateTexture(nil, "OVERLAY")
    marker.shade:SetAllPoints()
    marker.shade:SetColorTexture(0, 0, 0, 0.35)
    marker.count = marker:CreateFontString(nil, "OVERLAY")
    marker.count:SetFont(ns:GetFont(), 10, "OUTLINE")
    marker.count:SetPoint("CENTER", 0, 0)
    marker.setBorder = ns:Border(marker, { 0, 0, 0, 0.9 })
    marker:SetScript("OnClick", function(self) SelectCast(self.cast) end)
    ns:Tooltip(marker, function(tooltip, self)
        local cast = self.cast
        tooltip:SetText(cast.name .. (cast.count and (" (" .. cast.count .. ")") or ""), 1, 1, 1)
        tooltip:AddLine("Goes off at " .. ns:FormatTime(cast.at), 0.7, 0.7, 0.7)
        tooltip:AddLine(cast.assigned and "Something is assigned to it, click to see it" or "Click to assign something to it", Accent())
    end)
    page.markers[index] = marker
    return marker
end

--When one of your assignments lands, red when its spell won't be ready by then
local function Diamond(index)
    local diamond = page.diamonds[index]
    if diamond then
        return diamond
    end
    diamond = CreateFrame("Button", nil, page.you)
    diamond:SetSize(14, 14)
    diamond.texture = diamond:CreateTexture(nil, "ARTWORK")
    diamond.texture:SetAllPoints()
    diamond.texture:SetTexture(DIAMOND)
    diamond:SetScript("OnClick", function(self)
        if self.use.cast and self.use.cast.lane then
            SelectCast(self.use.cast)
        end
    end)
    ns:Tooltip(diamond, function(tooltip, self)
        local use = self.use
        if use.conflict then
            kit.ConflictTooltip(tooltip, { use = use })
            tooltip:AddLine(" ")
            tooltip:AddLine(use.entry, 1, 1, 1)
        else
            tooltip:SetText(use.entry, 1, 1, 1)
        end
        tooltip:AddLine("Lands at " .. ns:FormatTime(use.at), 0.7, 0.7, 0.7)
        if use.cast then
            tooltip:AddLine("For " .. use.cast.name .. (use.cast.count and (" (" .. use.cast.count .. ")") or ""), 0.7, 0.7, 0.7)
        end
    end)
    page.diamonds[index] = diamond
    return diamond
end

local function Pooled(pool, index, create)
    local item = pool[index]
    if not item then
        item = create()
        pool[index] = item
    end
    item:Show()
    return item
end

local function BuildPanel(frame)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("BOTTOMLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    panel:SetHeight(PANEL_H)
    page.panel = panel

    --Left: the selected cast and how far an assignment reaches
    local left = CreateFrame("Frame", nil, panel)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(LEFT_W)
    ns:SectionLabel(left, "Selected cast"):SetPoint("TOPLEFT", 0, 0)
    page.castIcon = left:CreateTexture(nil, "ARTWORK")
    page.castIcon:SetSize(36, 36)
    page.castIcon:SetPoint("TOPLEFT", 0, -18)
    page.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    page.castName = ns:Text(left, 15)
    page.castName:SetPoint("TOPLEFT", page.castIcon, "TOPRIGHT", 10, -1)
    page.castName:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    page.castInfo = ns:Text(left, 11, theme.dim)
    page.castInfo:SetPoint("BOTTOMLEFT", page.castIcon, "BOTTOMRIGHT", 10, 1)
    page.castInfo:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    page.scopeHelp = ns:Text(left, 10, theme.dim)
    page.scopeHelp:SetPoint("TOPLEFT", 0, -64)
    page.scopeHelp:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    page.scopeHelp:SetWordWrap(true)
    page.scopeHelp:SetHeight(28)
    page.scopeHelp:SetJustifyV("TOP")
    local function SetMode(mode)
        UI().timelineScope = mode
        Refresh(true)
    end
    page.scopeStages = ns:Segmented(left, {
        { text = "This cast", value = 'cast' }, { text = "Stage", value = 'stage' }, { text = "All stages", value = 'all' }
    }, LEFT_W, 26, function() return page.mode end, SetMode)
    page.scopeStages:SetPoint("TOPLEFT", 0, -96)
    page.scopeSimple = ns:Segmented(left, {
        { text = "This cast", value = 'cast' }, { text = "Every cast", value = 'all' }
    }, LEFT_W, 26, function() return page.mode end, SetMode)
    page.scopeSimple:SetPoint("TOPLEFT", 0, -96)
    page.replayFrom = ns:Button(left, "Replay from here", LEFT_W, 26, function()
        if ns:IsTesting() then
            ns:StopTest()
            return
        end
        local specKey, diffSlug, boss = kit.Selected()
        if page.selected then
            ns:StartTest(specKey, diffSlug, boss, nil, math.max(0, page.selected.at - 5))
        end
    end)
    page.replayFrom:SetPoint("BOTTOMLEFT", 0, 0)
    ns:Tooltip(page.replayFrom, "Replay from here", "Replays the recorded pull from 5 seconds before this cast, with your plan.")

    --Middle: what is assigned to it
    local middle = CreateFrame("Frame", nil, panel)
    page.middle = middle
    page.cardsLabel = ns:SectionLabel(middle, "Assigned to this cast")
    page.cardsLabel:SetPoint("TOPLEFT", 0, 0)
    local list = ns:ScrollList(middle)
    list:SetPoint("TOPLEFT", 0, -18)
    list:SetPoint("BOTTOMRIGHT", 0, 36)
    page.cardsScroll = list
    page.cardList = kit.NewCardList(list.content, function(keepRows) Refresh(keepRows) end)
    page.cardsEmpty = ns:Text(list.content, 12, theme.dim)
    page.cardsEmpty:SetPoint("TOPLEFT", 0, -4)
    page.cardsEmpty:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
    page.cardsEmpty:SetWordWrap(true)
    page.cardsEmpty:SetJustifyV("TOP")
    page.cardsEmpty:SetHeight(60)
    page.assign = ns:Button(middle, "+ Assign to this cast", 190, 28, function() page.Assign() end, true)
    page.assign:SetPoint("BOTTOMLEFT", 0, 0)

    --Right: what comes next from the line on the chart, or from just before the selected cast
    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(RIGHT_W)
    page.nextColumn = right
    page.nextLabel = ns:SectionLabel(right, "Next up")
    page.nextLabel:SetPoint("TOPLEFT", 0, 0)
    local function Row(y, height)
        local row = CreateFrame("Frame", nil, right)
        row:SetHeight(height)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", right, "RIGHT", 0, 0)
        row.background = ns:Fill(row, { 0, 0, 0, 0.35 })
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetWidth(2)
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(height - 8, height - 8)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.time = ns:Text(row, 12, theme.text, "RIGHT")
        row.time:SetPoint("RIGHT", -8, 0)
        row.label = ns:Text(row, 11)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.label:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
        return row
    end
    page.nextRows = {}
    for index = 1, 4 do
        page.nextRows[index] = Row(-18 - (index - 1) * 26, 24)
    end
    page.nextEmpty = ns:Text(right, 11, theme.dim)
    page.nextEmpty:SetPoint("TOPLEFT", 0, -20)
    page.nextEmpty:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    page.nextEmpty:SetWordWrap(true)
    page.nextEmpty:SetText("Nothing more of yours after this.")
    ns:SectionLabel(right, "Next reminder"):SetPoint("TOPLEFT", 0, -134)
    page.nextReminder = Row(-152, 30)
    page.nextReminder.background:SetColorTexture(theme.window[1], theme.window[2], theme.window[3], 1)
    page.nextReminder.fill = page.nextReminder:CreateTexture(nil, "BORDER")
    page.nextReminder.fill:SetPoint("TOPLEFT", page.nextReminder.icon, "TOPRIGHT", 0, 4)
    page.nextReminder.fill:SetPoint("BOTTOMLEFT", page.nextReminder.icon, "BOTTOMRIGHT", 0, -4)
    page.nextReminder.fill:SetWidth(90)
    local note = ns:Text(right, 10, theme.dim)
    note:SetPoint("BOTTOMLEFT", 0, 0)
    note:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    note:SetWordWrap(true)
    note:SetText("From the line on the chart while a replay runs, otherwise from 5 seconds before the selected cast.")
end

------------------------------------------------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------------------------------------------------

--A stage's name over its band: '1 · FURY OF THE SERPENT MOTHER', or 'INTERMISSION'
local function StageLabel(boss, stage)
    if kit.IsIntermission(stage) then
        return kit.ShortStageName(boss, stage):upper()
    end
    local name = kit.HasStages(boss) and kit.StageName(boss, stage) or nil
    local rest = name and name:match(":%s*(.+)$")
    return (stage .. (rest and (" · " .. rest) or "")):upper()
end

local function DrawStages(stages, boss)
    for _, pool in ipairs({ page.bands, page.edges, page.stageLabels, page.stageBoxes }) do
        for _, item in ipairs(pool) do
            item:Hide()
        end
    end
    local r, g, b = ns:GetAccent()
    local edges, boxes = 0, 0
    for index, stage in ipairs(stages) do
        local finish = stages[index + 1] and stages[index + 1].at or page.duration
        local x, width = X(stage.at), math.max(1, X(finish) - X(stage.at))
        local intermission = kit.IsIntermission(stage.stage)
        local band = Pooled(page.bands, index, function() return page.chart:CreateTexture(nil, "BACKGROUND", nil, 1) end)
        band:ClearAllPoints()
        band:SetPoint("TOPLEFT", page.chart, "TOPLEFT", x, -RULER_H)
        band:SetPoint("BOTTOMLEFT", page.chart, "BOTTOMLEFT", x, 1)
        band:SetWidth(width)
        local label = Pooled(page.stageLabels, index, function() return ns:Text(page.stageRow, 10, theme.text) end)
        label:ClearAllPoints()
        label:SetText(StageLabel(boss, stage.stage))
        if intermission then
            --An intermission stands out: tinted, edged and its name on an accent box
            band:SetColorTexture(r, g, b, 0.11)
            for _, edgeX in ipairs({ x, x + width - 1 }) do
                edges = edges + 1
                local edge = Pooled(page.edges, edges, function() return page.chart:CreateTexture(nil, "BACKGROUND", nil, 2) end)
                edge:ClearAllPoints()
                edge:SetPoint("TOPLEFT", page.chart, "TOPLEFT", edgeX, -RULER_H)
                edge:SetPoint("BOTTOMLEFT", page.chart, "BOTTOMLEFT", edgeX, 1)
                edge:SetWidth(1)
                edge:SetColorTexture(r, g, b, 0.7)
            end
            boxes = boxes + 1
            local box = Pooled(page.stageBoxes, boxes, function() return page.stageRow:CreateTexture(nil, "ARTWORK") end)
            box:ClearAllPoints()
            box:SetPoint("LEFT", page.stageRow, "LEFT", x, 0)
            box:SetSize(width, 18)
            box:SetColorTexture(r, g, b, 0.9)
            label:SetPoint("CENTER", box, "CENTER", 0, 0)
            label:SetWidth(math.max(1, width - 4))
            label:SetJustifyH("CENTER")
            label:SetTextColor(0.03, 0.07, 0.05, 1)
        else
            band:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.035 or 0.015)
            label:SetPoint("LEFT", page.stageRow, "LEFT", x + 6, 0)
            label:SetWidth(math.max(1, width - 10))
            label:SetJustifyH("LEFT")
            label:SetTextColor(1, 1, 1, 0.75)
        end
    end
    --The time bar
    for _, pool in ipairs({ page.minorTicks, page.majorTicks, page.tickLabels }) do
        for _, item in ipairs(pool) do
            item:Hide()
        end
    end
    local minor, major = 0, 0
    for at = 0, page.duration, 10 do
        local isMajor = at % 30 == 0
        local tick
        if isMajor then
            major = major + 1
            tick = Pooled(page.majorTicks, major, function() return page.ticksRow:CreateTexture(nil, "ARTWORK") end)
            tick:SetColorTexture(1, 1, 1, 0.35)
            tick:SetSize(1, 7)
            local label = Pooled(page.tickLabels, major, function() return ns:Text(page.ticksRow, 10, theme.dim, "CENTER") end)
            label:ClearAllPoints()
            label:SetPoint("BOTTOM", page.ticksRow, "BOTTOMLEFT", X(at) + (at == 0 and 14 or 0), 9)
            label:SetText(ns:FormatTime(at))
        else
            minor = minor + 1
            tick = Pooled(page.minorTicks, minor, function() return page.ticksRow:CreateTexture(nil, "ARTWORK") end)
            tick:SetColorTexture(1, 1, 1, 0.14)
            tick:SetSize(1, 4)
        end
        tick:ClearAllPoints()
        tick:SetPoint("BOTTOMLEFT", page.ticksRow, "BOTTOMLEFT", X(at), 1)
    end
end

local function DrawLanes(lanes, selected)
    for _, lane in ipairs(page.lanes) do
        lane:Hide()
    end
    for _, marker in ipairs(page.markers) do
        marker:Hide()
    end
    local r, g, b = ns:GetAccent()
    local markers = 0
    for index, info in ipairs(lanes) do
        local lane = Lane(index)
        lane:ClearAllPoints()
        lane:SetPoint("TOPLEFT", 0, -(index - 1) * LANE_H)
        lane:SetPoint("RIGHT", page.lanesList.content, "RIGHT", 0, 0)
        local name, icon = kit.SpellNameAndIcon(info.ability.spellId, info.ability.name)
        lane.label:SetText(name)
        lane.icon:SetTexture(icon)
        local isSelected = selected and selected.lane == info
        lane.info, lane.selected = info, isSelected
        lane.background:SetColorTexture(1, 1, 1, isSelected and 0.04 or 0)
        lane.label:SetTextColor(1, 1, 1, isSelected and 1 or 0.75)
        lane:Show()
        for _, cast in ipairs(info.casts) do
            markers = markers + 1
            local marker = Marker(markers)
            marker.cast = cast
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", lane, "LEFT", X(cast.at), 0)
            marker.icon:SetTexture(icon)
            marker.count:SetText(cast.count and tostring(cast.count) or "")
            if cast == selected then
                marker.setBorder(1, 1, 1, 1)
                marker.shade:SetColorTexture(0, 0, 0, 0.1)
            elseif cast.assigned then
                marker.setBorder(r, g, b, 1)
                marker.shade:SetColorTexture(0, 0, 0, 0.2)
            else
                marker.setBorder(0, 0, 0, 0.9)
                marker.shade:SetColorTexture(0, 0, 0, 0.45)
            end
            marker:Show()
        end
    end
    page.lanesList:SetContentHeight(#lanes * LANE_H)
end

local function DrawYou(timeline)
    for _, diamond in ipairs(page.diamonds) do
        diamond:Hide()
    end
    local r, g, b = ns:GetAccent()
    page.youFill:SetColorTexture(r, g, b, 0.04)
    page.youEdge:SetColorTexture(r, g, b, 0.25)
    page.youLabel:SetTextColor(r, g, b, 1)
    for index, use in ipairs(timeline.uses) do
        local diamond = Diamond(index)
        diamond.use = use
        diamond:ClearAllPoints()
        diamond:SetPoint("CENTER", page.you, "LEFT", X(use.at), 0)
        if use.conflict then
            diamond.texture:SetVertexColor(ErrorColor())
        else
            diamond.texture:SetVertexColor(r, g, b, 1)
        end
        diamond:Show()
    end
end

--What comes next of yours from a point of the pull: the line on the chart while a replay runs, otherwise 5 seconds
--before the selected cast. Your presses with the seconds until each, then the next reminder
local function RefreshNextUp()
    local timeline = page.timeline
    if not timeline or not page.duration then
        return
    end
    local point = (page.dragging and page.cursor) or page.now or page.cursor or (page.selected and math.max(0, page.selected.at - 5)) or 0
    page.point = point
    page.nextLabel:SetText("NEXT UP AT " .. ns:FormatTime(point))
    local uses = {}
    for _, use in ipairs(timeline.uses) do
        if use.at >= point then
            table.insert(uses, use)
        end
    end
    table.sort(uses, function(a, b) return a.at < b.at end)
    local r, g, b = ns:GetAccent()
    local function Seconds(value)
        return value < 10 and string.format("%.1f", value) or tostring(math.floor(value + 0.5))
    end
    for index, row in ipairs(page.nextRows) do
        local use = uses[index]
        row:SetShown(use ~= nil)
        if use then
            row.icon:SetTexture(kit.EntryIcon(use.entry))
            row.label:SetText(use.entry .. (use.conflict and "  ·  not ready" or ""))
            row.time:SetText(Seconds(use.at - point))
            row:SetAlpha(use.conflict and 0.55 or 1)
            row.bar:SetColorTexture(r, g, b, index == 1 and 1 or 0.45)
            if index == 1 then
                row.time:SetTextColor(r, g, b, 1)
            else
                row.time:SetTextColor(1, 1, 1, 0.9)
            end
        end
    end
    page.nextEmpty:SetShown(#uses == 0)
    local reminder
    for _, candidate in ipairs(timeline.reminders) do
        if candidate.at >= point then
            reminder = candidate
            break
        end
    end
    local row = page.nextReminder
    row:SetShown(reminder ~= nil)
    if reminder then
        row.icon:SetTexture(reminder.icon or kit.QUESTION_MARK)
        row.label:SetText((reminder.approximate and "~ " or "") .. reminder.text)
        row.time:SetText(Seconds(reminder.at - point))
        row.fill:SetColorTexture(r, g, b, 0.32)
        row.bar:SetColorTexture(0, 0, 0, 0)
    end
end

--While a replay of the pull runs, a line shows how far it is, with the time on the time bar
local function UpdatePlayhead()
    if not page or not page.duration then
        return
    end
    local testing = ns:IsTesting() and not ns.fight.test.ability
    local now = testing and (GetTime() - ns.fight.start) or nil
    if now and (now < 0 or now > page.duration) then
        now = nil
    end
    page.now = now
    --The line shows where it is dragged, else how far a replay is, else where it was dropped
    local shown = (page.dragging and page.cursor) or now or page.cursor
    if shown and page.chart:IsShown() then
        local r, g, b = ns:GetAccent()
        local x = X(shown)
        page.playhead:SetColorTexture(r, g, b, 1)
        page.glow:SetColorTexture(r, g, b, 0.22)
        for _, line in ipairs({ page.playhead, page.glow }) do
            line:ClearAllPoints()
            line:SetPoint("TOP", page.chart, "TOPLEFT", x, -RULER_H)
            line:SetPoint("BOTTOM", page.chart, "BOTTOMLEFT", x, 1)
            line:Show()
        end
        page.bubble.fill:SetColorTexture(r, g, b, 1)
        page.bubble.text:SetText(ns:FormatTime(shown))
        page.bubble:ClearAllPoints()
        page.bubble:SetPoint("TOP", page.chart, "TOPLEFT", x, -5)
        page.bubble:Show()
    else
        page.playhead:Hide()
        page.glow:Hide()
        page.bubble:Hide()
    end
    RefreshNextUp()
end

local function UpdateReplayButtons()
    local testing = ns:IsTesting()
    page.replay.label:SetText(testing and "Stop test" or (page.cursor and ("Replay from " .. ns:FormatTime(page.cursor))) or "Replay pull")
    page.replayFrom.label:SetText(testing and "Stop test" or (page.selected and ("Replay from " ..
        ns:FormatTime(math.max(0, page.selected.at - 5))) or "Replay from here"))
end

--The cast that was selected, or the first one with something assigned, or the first one
local function FindSelected(lanes)
    local saved = UI().timelineCast
    local first, firstAssigned
    for _, lane in ipairs(lanes) do
        for _, cast in ipairs(lane.casts) do
            if saved and lane.key == saved.key and math.abs(cast.at - saved.at) < 0.05 then
                return cast
            end
            first = first or cast
            if cast.assigned and (not firstAssigned or cast.at < firstAssigned.at) then
                firstAssigned = cast
            end
        end
    end
    local cast = firstAssigned or first
    UI().timelineCast = cast and { key = cast.lane.key, at = cast.at } or nil
    return cast
end

--The selected cast's assignments: those for its stage and those for every stage, kept as they are on keepRows so a new
--one without a spell yet stays
local function RefreshCast(cast, timeline, boss, planText, keepRows)
    local hasStages = kit.HasStages(boss)
    page.mode = ScopeMode(boss, cast)
    page.scopeStages:SetShown(hasStages)
    page.scopeSimple:SetShown(not hasStages)
    if not cast then
        page.castName:SetText("No cast selected")
        page.castInfo:SetText("")
        page.castIcon:SetTexture(kit.QUESTION_MARK)
        page.scopeHelp:SetText("Click a cast on the timeline to see what is assigned to it.")
        kit.FillCards(page.cardList, {})
        page.cardsEmpty:Hide()
        page.assign:Hide()
        page.groups = nil
        return
    end
    local ability = cast.lane.ability
    local name, icon = kit.SpellNameAndIcon(cast.spellId, cast.name)
    page.castIcon:SetTexture(icon)
    page.castName:SetText(CastTitle(cast))
    local stageName = hasStages and kit.ShortStageName(boss, cast.stage) or nil
    page.castInfo:SetText("Goes off at " .. ns:FormatTime(cast.at) .. (stageName and (" in " .. stageName) or ""))
    if hasStages then
        page.scopeHelp:SetText("Assign to this cast only, every cast in " .. stageName .. ", or every cast in every stage.")
        page.scopeStages.buttons[2].label:SetText(stageName)
    else
        page.scopeHelp:SetText("Assign to this cast only, or to every cast of " .. name .. ".")
    end
    page.scopeStages:Refresh()
    page.scopeSimple:Refresh()
    for _, segmented in ipairs({ page.scopeStages, page.scopeSimple }) do
        segmented.buttons[1]:SetEnabled(cast.count ~= nil)
        segmented.buttons[1]:SetAlpha(cast.count and 1 or 0.4)
    end

    --The timeline is built again on every redraw, so the cast is known by its lane and time
    local castKey = cast.lane.key .. '@' .. cast.at
    local same = page.groups and page.groups.castKey == castKey
    if not keepRows or not same then
        local groups = { castKey = castKey, list = {} }
        local function Group(scope)
            local group = { ability = ability, scope = scope, assignments = ns:GetAbilityAssignments(planText, ability, scope) }
            table.insert(groups.list, group)
            return group
        end
        groups.stage = hasStages and Group(cast.stage) or nil
        groups.all = Group('all')
        page.groups = groups
        if not same then
            kit.ResetCards(page.cardList)
        end
    end
    local items = {}
    for _, group in ipairs(page.groups.list) do
        for _, assignment in ipairs(group.assignments) do
            if Covers(assignment, cast.count) then
                local where = group.scope ~= 'all' and (" in " .. kit.ShortStageName(boss, group.scope)) or
                    (hasStages and " in every stage" or "")
                table.insert(items, { group = group, assignment = assignment, ability = ability, scope = group.scope,
                    note = "Lands " .. kit.TimingText(assignment.before or 0) .. " " .. kit.CastsText(assignment) .. where })
            end
        end
    end
    page.cardList.timeline = timeline
    local y = 0
    if #items == 0 then
        page.cardsEmpty:SetText("Nothing assigned to this cast yet. Pick how far it reaches on the left and assign a ramp, cooldown or trinket.")
        page.cardsEmpty:Show()
        y = 52
    else
        page.cardsEmpty:Hide()
    end
    y = kit.FillCards(page.cardList, items, y)
    page.cardsScroll:SetContentHeight(y + 4)
    page.assign:Show()
    if page.mode == 'cast' then
        page.assign.label:SetText("+ Assign to cast " .. cast.count)
    elseif page.mode == 'stage' then
        page.assign.label:SetText("+ Assign to " .. stageName)
    else
        page.assign.label:SetText(hasStages and "+ Assign to all stages" or "+ Assign to every cast")
    end
end

--Where the cursor is on the time bar, as a time of the pull
local function CursorTime()
    local x = GetCursorPosition()
    local scale = page.ticksRow:GetEffectiveScale() or 1
    local left = page.ticksRow:GetLeft() or 0
    local at = (x / scale - left - NAME_W) / TrackWidth() * page.duration
    return math.max(0, math.min(page.duration, at))
end

--Dragging the line along the time bar. While a replay runs it jumps to where the line is let go, otherwise the line
--stays there for Next up and Replay pull
local function StartDrag()
    if not page.duration then
        return
    end
    page.dragging = true
    page.cursor = CursorTime()
    UpdatePlayhead()
    page.ticksRow:SetScript("OnUpdate", function()
        page.cursor = CursorTime()
        UpdatePlayhead()
    end)
end

local function StopDrag()
    page.ticksRow:SetScript("OnUpdate", nil)
    if not page.dragging then
        return
    end
    page.dragging = false
    page.cursor = CursorTime()
    if ns:IsTesting() and not ns.fight.test.ability then
        local specKey, diffSlug, boss = kit.Selected()
        local from = page.cursor
        page.cursor = nil
        ns:StopTest()
        ns:StartTest(specKey, diffSlug, boss, nil, from)
    end
    UpdatePlayhead()
    UpdateReplayButtons()
end

function Refresh(keepRows)
    if not page then
        return
    end
    ns:RefreshBossBar()
    local specKey, diffSlug, boss = kit.Selected()
    local record, recordSlug = ns:GetRecordingFor(boss, diffSlug)
    local planText = kit.GetPlanText()
    --A dropped line belongs to the pull it was dropped on
    local recordKey = record and (boss .. ':' .. recordSlug)
    if recordKey ~= page.recordKey then
        page.cursor, page.recordKey = nil, recordKey
    end
    page.chart:SetShown(record ~= nil)
    page.panel:SetShown(record ~= nil)
    page.onlyAssigned:SetShown(record ~= nil)
    page.empty:SetShown(record == nil)
    page.replay:SetEnabled(record ~= nil or ns:IsTesting())
    page.replay:SetAlpha((record or ns:IsTesting()) and 1 or 0.4)
    if not record then
        page.duration = nil
        page.info:SetText("No recorded pull")
        page.empty:SetText("No pull of " .. ns.bosses[boss].name .. " on " .. ns.difficulties[UI().difficulty].name ..
            " recorded yet.\n\nPull it once with BigWigs or DBM: every pull is recorded, with the stages and the bars of " ..
            "the boss's abilities, a wipe too. The timeline then shows when each ability went off, and you can assign to " ..
            "any cast of it here.\n\nNot pulled it yet? Someone who has can share it: Share on the Plans page, With " ..
            "recorded pulls ticked, and Import the string they send. Boss mods only learn the timers in the fight, so " ..
            "there is no way to know them before a first pull.")
        page.groups = nil
        UpdateReplayButtons()
        return
    end
    --Next up only shows when the window is wide enough to keep room for the assignment cards
    local showNext = ns:WindowContentWidth() >= 900
    page.nextColumn:SetShown(showNext)
    page.middle:ClearAllPoints()
    page.middle:SetPoint("TOPLEFT", LEFT_W + 18, 0)
    page.middle:SetPoint("BOTTOMRIGHT", showNext and (-RIGHT_W - 18) or 0, 0)
    local timeline = ns:BuildTimeline(specKey, planText, record, boss)
    page.timeline, page.duration = timeline, math.max(1, timeline.duration)
    local borrowed = ""
    if recordSlug ~= diffSlug then
        for _, difficulty in pairs(ns.difficulties) do
            if difficulty.slug == recordSlug then
                borrowed = "  ·  |cffffd100the " .. difficulty.name .. " pull, there is no " .. ns.difficulties[UI().difficulty].name .. " pull yet|r"
            end
        end
    end
    page.info:SetText((record.shared and "Shared pull of " or "Recorded pull of ") .. ns:FormatTime(record.duration) ..
        (record.date and (" on " .. record.date) or "") .. borrowed ..
        (timeline.conflicts > 0 and ("  ·  |cffff5a4d" .. timeline.conflicts .. " not ready in time|r") or ""))
    page.onlyAssigned:Refresh()
    local lanes = Lanes(timeline, boss, planText)
    local selected = FindSelected(lanes)
    page.selected = selected
    DrawStages(Stages(timeline), boss)
    DrawLanes(lanes, selected)
    DrawYou(timeline)
    RefreshCast(selected, timeline, boss, planText, keepRows)
    UpdatePlayhead()
    UpdateReplayButtons()
end

--Adds an assignment for the selected cast, as far as the switch on the left says, and opens the menu of what to cast
local function Assign()
    local cast, groups = page.selected, page.groups
    if not cast or not groups then
        return
    end
    local assignment = { before = 0, entry = '' }
    local group = groups.all
    if page.mode == 'cast' then
        group = groups.stage or groups.all
        assignment.casts = { cast.count }
    elseif page.mode == 'stage' then
        group = groups.stage or groups.all
    end
    table.insert(group.assignments, assignment)
    Refresh(true)
    for _, card in ipairs(page.cardList.cards) do
        if card:IsShown() and card.assignment == assignment then
            kit.OpenEntryMenu(card)
        end
    end
end

ns:RegisterPage('timeline', "Timeline", 2, function(frame)
    kit = ns.plannerKit
    page = { frame = frame, Assign = Assign, StartDrag = StartDrag, StopDrag = StopDrag }
    BuildToolbar(frame)
    BuildChart(frame)
    BuildPanel(frame)
    ns:SetPageTestHandler('timeline', function()
        UpdatePlayhead()
        UpdateReplayButtons()
    end)
end, function()
    Refresh()
end, { icon = 'rail-timeline', bossBar = true })

--For tests
function ns:GetTimelinePageWidgets()
    return page
end
