local _, ns = ...

--The Timeline page: the recorded pull of the selected boss as a chart. Every ability has a lane with its casts,
--numbered like the boss mod counts them, the stages are bands behind them and the bottom lane shows when each of your
--assignments lands, red when the spell won't be ready. Click a cast to see what is assigned to it and to assign
--something: to that cast only, every cast in its stage or every cast in every stage

local theme = ns.theme
local kit
local NAME_W = 150
local TOOLBAR_H = 36
local TICKS_H = 18
local STAGE_H = 22
local LANE_H = 28
local YOU_H = 34
local PANEL_H = 214
local LEFT_W = 240
local RIGHT_W = 210
local CONTENT_W = 932
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

local function TrackWidth()
    local width = page.frame:GetWidth()
    if not width or width < 400 then
        width = CONTENT_W
    end
    return width - NAME_W - 16
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
        ns:StartTest(specKey, diffSlug, boss)
    end, true)
    page.replay:SetPoint("TOPRIGHT", 0, 0)
    ns:Tooltip(page.replay, "Replay pull", "Runs the recorded pull again with your plan, so its reminders show and speak as they " ..
        "would in the raid. Nothing has to be pulled, it works anywhere.")
end

local function BuildChart(frame)
    local chart = CreateFrame("Frame", nil, frame)
    chart:SetPoint("TOPLEFT", 0, -TOOLBAR_H)
    chart:SetPoint("BOTTOMRIGHT", 0, PANEL_H + 12)
    ns:Fill(chart, theme.well)
    ns:Border(chart, theme.border)
    page.chart = chart
    page.bands, page.ticks, page.stageLabels = {}, {}, {}

    page.ticksRow = CreateFrame("Frame", nil, chart)
    page.ticksRow:SetPoint("TOPLEFT", 0, 0)
    page.ticksRow:SetPoint("TOPRIGHT", 0, 0)
    page.ticksRow:SetHeight(TICKS_H)
    page.stageRow = CreateFrame("Frame", nil, chart)
    page.stageRow:SetPoint("TOPLEFT", 0, -TICKS_H)
    page.stageRow:SetPoint("TOPRIGHT", 0, -TICKS_H)
    page.stageRow:SetHeight(STAGE_H)
    local stageName = ns:SectionLabel(page.stageRow, "Stage")
    stageName:SetPoint("LEFT", 10, 0)
    local rule = page.stageRow:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetColorTexture(1, 1, 1, 0.06)

    page.lanesList = ns:ScrollList(chart)
    page.lanesList:SetPoint("TOPLEFT", 0, -TICKS_H - STAGE_H)
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
    page.playhead = page.overlay:CreateTexture(nil, "OVERLAY")
    page.playhead:SetWidth(1)
    page.playhead:Hide()

    page.empty = ns:Text(frame, 13, theme.dim)
    page.empty:SetPoint("TOPLEFT", 0, -TOOLBAR_H - 16)
    page.empty:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    page.empty:SetWordWrap(true)
    page.empty:SetJustifyV("TOP")
    page.empty:SetHeight(120)
end

local function SelectCast(cast)
    local _, _, boss = kit.Selected()
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
    middle:SetPoint("TOPLEFT", LEFT_W + 18, 0)
    middle:SetPoint("BOTTOMRIGHT", -RIGHT_W - 18, 0)
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

    --Right: your reminders leading up to it
    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(RIGHT_W)
    ns:SectionLabel(right, "Your reminders before it"):SetPoint("TOPLEFT", 0, 0)
    page.reminderRows = {}
    for index = 1, 6 do
        local row = CreateFrame("Frame", nil, right)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 0, -18 - (index - 1) * 26)
        row:SetPoint("RIGHT", right, "RIGHT", 0, 0)
        row.background = ns:Fill(row, { 0, 0, 0, 0.3 })
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetWidth(2)
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.time = ns:Text(row, 11, theme.text, "RIGHT")
        row.time:SetPoint("RIGHT", -8, 0)
        row.label = ns:Text(row, 11)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.label:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
        page.reminderRows[index] = row
    end
    page.remindersEmpty = ns:Text(right, 11, theme.dim)
    page.remindersEmpty:SetPoint("TOPLEFT", 0, -20)
    page.remindersEmpty:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    page.remindersEmpty:SetWordWrap(true)
end

------------------------------------------------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------------------------------------------------

local function DrawStages(stages, boss)
    for _, band in ipairs(page.bands) do
        band:Hide()
    end
    for _, label in ipairs(page.stageLabels) do
        label:Hide()
    end
    local r, g, b = ns:GetAccent()
    for index, stage in ipairs(stages) do
        local finish = stages[index + 1] and stages[index + 1].at or page.duration
        local x, width = X(stage.at), math.max(1, X(finish) - X(stage.at))
        local band = Pooled(page.bands, index, function() return page.chart:CreateTexture(nil, "BACKGROUND", nil, 1) end)
        band:ClearAllPoints()
        band:SetPoint("TOPLEFT", page.chart, "TOPLEFT", x, -TICKS_H)
        band:SetPoint("BOTTOMLEFT", page.chart, "BOTTOMLEFT", x, 1)
        band:SetWidth(width)
        if kit.IsIntermission(stage.stage) then
            band:SetColorTexture(r, g, b, 0.07)
        else
            band:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.035 or 0.015)
        end
        local label = Pooled(page.stageLabels, index, function() return ns:Text(page.stageRow, 10, theme.text) end)
        label:ClearAllPoints()
        label:SetPoint("LEFT", page.stageRow, "LEFT", x + 6, 0)
        label:SetWidth(math.max(1, width - 10))
        label:SetText((kit.HasStages(boss) and kit.StageName(boss, stage.stage) or ("Stage " .. stage.stage)):upper())
        if kit.IsIntermission(stage.stage) then
            label:SetTextColor(r, g, b, 1)
        else
            label:SetTextColor(1, 1, 1, 0.75)
        end
    end
    --Minutes along the top, or half minutes for a short pull
    for _, tick in ipairs(page.ticks) do
        tick:Hide()
    end
    local step = page.duration >= 150 and 60 or 30
    local index = 0
    for at = 0, page.duration, step do
        index = index + 1
        local tick = Pooled(page.ticks, index, function() return ns:Text(page.ticksRow, 10, theme.section) end)
        tick:ClearAllPoints()
        tick:SetPoint("LEFT", page.ticksRow, "LEFT", X(at) - (at == 0 and 0 or 12), 0)
        tick:SetText(ns:FormatTime(at))
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

--While a replay of the pull runs, a line shows how far it is
local function UpdatePlayhead()
    if not page or not page.duration then
        return
    end
    local testing = ns:IsTesting() and not ns.fight.test.ability
    local now = testing and (GetTime() - ns.fight.start) or nil
    if now and now >= 0 and now <= page.duration and page.chart:IsShown() then
        page.playhead:SetColorTexture(Accent())
        page.playhead:ClearAllPoints()
        page.playhead:SetPoint("TOPLEFT", page.chart, "TOPLEFT", X(now), -TICKS_H)
        page.playhead:SetPoint("BOTTOMLEFT", page.chart, "BOTTOMLEFT", X(now), 1)
        page.playhead:Show()
        page.now = now
    else
        page.playhead:Hide()
        page.now = nil
    end
end

local function UpdateReplayButtons()
    local testing = ns:IsTesting()
    page.replay.label:SetText(testing and "Stop test" or "Replay pull")
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

--Your reminders in the 30 seconds before the selected cast, and the ones for it
local function RefreshReminders(cast, timeline)
    local shown = {}
    if cast then
        for _, reminder in ipairs(timeline.reminders) do
            if reminder.cast == cast or (reminder.at >= cast.at - 30 and reminder.at <= cast.at + 1) then
                table.insert(shown, reminder)
            end
        end
    end
    local r, g, b = ns:GetAccent()
    for index, row in ipairs(page.reminderRows) do
        local reminder = shown[index]
        row:SetShown(reminder ~= nil)
        if reminder then
            local conflict = reminder.use and reminder.use.conflict
            row.icon:SetTexture(reminder.icon or kit.QUESTION_MARK)
            row.label:SetText((reminder.approximate and "~ " or "") .. reminder.text)
            row.time:SetText(ns:FormatTime(reminder.at))
            if conflict then
                row.bar:SetColorTexture(ErrorColor())
                row.time:SetTextColor(ErrorColor())
            else
                row.bar:SetColorTexture(r, g, b, reminder.cast == cast and 1 or 0.45)
                row.time:SetTextColor(r, g, b, reminder.cast == cast and 1 or 0.7)
            end
        end
    end
    page.remindersEmpty:SetShown(cast ~= nil and #shown == 0)
    page.remindersEmpty:SetText("None in the 30 seconds before it.")
end

function Refresh(keepRows)
    if not page then
        return
    end
    ns:RefreshBossBar()
    local specKey, diffSlug, boss = kit.Selected()
    local record = ns:GetRecording(boss, diffSlug)
    local planText = kit.GetPlanText()
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
            "the boss's abilities. The timeline then shows when each ability went off, and you can assign to any cast " ..
            "of it here.")
        page.groups = nil
        UpdateReplayButtons()
        return
    end
    local timeline = ns:BuildTimeline(specKey, planText, record, boss)
    page.timeline, page.duration = timeline, math.max(1, timeline.duration)
    page.info:SetText("Recorded pull of " .. ns:FormatTime(record.duration) .. " on " .. record.date ..
        (timeline.conflicts > 0 and ("  ·  |cffff5a4d" .. timeline.conflicts .. " not ready in time|r") or ""))
    page.onlyAssigned:Refresh()
    local lanes = Lanes(timeline, boss, planText)
    local selected = FindSelected(lanes)
    page.selected = selected
    DrawStages(Stages(timeline), boss)
    DrawLanes(lanes, selected)
    DrawYou(timeline)
    RefreshCast(selected, timeline, boss, planText, keepRows)
    RefreshReminders(selected, timeline)
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
    page = { frame = frame, Assign = Assign }
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
