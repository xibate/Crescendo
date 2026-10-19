local _, ns = ...

--The Plans page: the boss's abilities on the left, with a tab for every stage, and on the right the selected ability's
--assignments: ramps or spells for every cast or chosen casts, landing a number of seconds before the ability. The raid,
--boss, difficulty and spec are picked in the window's header. Assignments are saved as ability lines in the boss's
--plan, which Plan text shows in full and Share sends to others. The Timeline page edits the same assignments

local theme = ns.theme
local LIST_W = 260
local RIGHT_X = 274
local TABS_H = 36
local BOTTOM_H = 40
local PREVIEW_W = 250
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

local function ErrorColor(alpha)
    return theme.error[1], theme.error[2], theme.error[3], alpha or 1
end

------------------------------------------------------------------------------------------------------------------------
-- Selection
------------------------------------------------------------------------------------------------------------------------

local function FirstBoss()
    return ns.raids[1].bosses[1].encounterId
end

--The spec selected in the window, the player's own spec at first
function ns:SelectedSpec()
    local ui = UI()
    if not ns.specNames[ui.spec or ''] then
        ui.spec = ns:GetPlayerSpecKey() or 'Discipline'
    end
    return ui.spec
end

function ns:SpecMenuItems()
    local items = {}
    for _, info in pairs(ns.specs) do
        table.insert(items, { text = info.name, value = info.key })
    end
    table.sort(items, function(a, b) return a.text < b.text end)
    return items
end

local function Selected()
    local ui = UI()
    if not ns.difficulties[ui.difficulty or 0] then
        ui.difficulty = 16
    end
    if not ns.bosses[ui.boss or 0] then
        ui.boss = FirstBoss()
    end
    return ns:SelectedSpec(), ns.difficulties[ui.difficulty].slug, ui.boss
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
--A boss can have two abilities with the same name, but a seen or planned ability with a listed name is the same one.
--On Heroic the abilities that are only on Mythic are left out
function ns:GetPlannerAbilities(encounterId, planText, heroic)
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
        if not (heroic and ability.mythic) then
            Add({ spellId = ability.spellId, name = ability.name, group = ability.group, phases = ability.phases, mythic = ability.mythic }, false)
        end
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

------------------------------------------------------------------------------------------------------------------------
-- What an assignment does
------------------------------------------------------------------------------------------------------------------------

local function Seconds(value)
    return string.format("%gs", math.floor(value * 10 + 0.5) / 10)
end

--The first casts of a pattern, like '2, 4, 6...'
local function CastNumbers(every, from)
    return from .. ", " .. (from + every) .. ", " .. (from + 2 * every) .. "..."
end

--Which casts an assignment is for, by their numbers: 'every cast', 'casts 2, 4' or 'casts 1, 4, 7...'
local function CastsText(assignment)
    if assignment.casts then
        return (#assignment.casts == 1 and "cast " or "casts ") .. table.concat(assignment.casts, ', ')
    end
    if assignment.every and assignment.every > 1 then
        return "casts " .. CastNumbers(assignment.every, assignment.from or 1)
    end
    return "every cast"
end

--What the Which casts box shows for an assignment
local function CastsBoxText(assignment)
    if assignment.casts then
        return table.concat(assignment.casts, ',')
    end
    if assignment.every then
        return "every " .. assignment.every .. ((assignment.from or 1) > 1 and (" from " .. assignment.from) or "")
    end
    return ""
end

local function TimingText(before)
    if before > 0 then
        return Seconds(before) .. " before"
    elseif before < 0 then
        return Seconds(-before) .. " after"
    end
    return "at"
end

--The steps of an assignment, each with how many seconds before the ability it shows, or nil when the ramp or spell isn't known
local function AssignmentSchedule(assignment)
    local steps = ns:GetEntrySteps(ns:SelectedSpec(), assignment.entry or '')
    if not steps then
        return nil
    end
    local schedule = {}
    for _, step in ipairs(steps) do
        if ns:ShouldUseStep(step) then
            table.insert(schedule, { step = step, before = (assignment.before or 0) + (step.offset or 0) })
        end
    end
    table.sort(schedule, function(a, b) return a.before > b.before end)
    return schedule
end

--What an assignment does, in a line, and whether something is wrong with it
local function DescribeAssignment(assignment)
    local entry = assignment.entry or ''
    if not entry:find('%S') then
        return "Pick a ramp, spell or trinket", false
    end
    local schedule = AssignmentSchedule(assignment)
    if not schedule then
        return "Not a ramp, a spell you know or an equipped trinket", true
    end
    local before = assignment.before or 0
    local text = "Lands " .. TimingText(before) .. " " .. CastsText(assignment)
    local first = schedule[1]
    if first and first.before > before then
        text = text .. "  ·  first message " .. TimingText(first.before) .. " it"
    end
    return text, false
end

--Every message of an assignment and when it shows, in the tooltip of its description
local function AssignmentTooltip(tooltip, assignment, append)
    local schedule = assignment and AssignmentSchedule(assignment)
    if not schedule or #schedule == 0 then
        return append or false
    end
    if append then
        tooltip:AddLine(assignment.entry, 1, 1, 1)
    else
        tooltip:SetText(assignment.entry, 1, 1, 1)
    end
    tooltip:AddLine("When each message shows, counted from the boss ability:", 0.7, 0.7, 0.7, true)
    for _, item in ipairs(schedule) do
        local when
        if item.step.chargesOf then
            when = "charges"
        else
            when = TimingText(item.before)
        end
        tooltip:AddDoubleLine(item.step.text, when, 1, 1, 1, Accent())
    end
    if ns:FindRamp(ns:SelectedSpec(), assignment.entry) then
        tooltip:AddLine("The steps come from the ramp, change them on the Ramps page. Steps counted in global cooldowns use your haste.", 0.7, 0.7, 0.7, true)
    elseif ns:FindTrinket(assignment.entry) then
        tooltip:AddLine("A trinket gets a countdown first, its length is set on the Display page.", 0.7, 0.7, 0.7, true)
    else
        tooltip:AddLine("A spell gets a countdown first, its length is set on the Display page.", 0.7, 0.7, 0.7, true)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Testing one cast
------------------------------------------------------------------------------------------------------------------------

local Refresh
local ConflictTooltip
local CopyMenuItems, CopyPlanTo, HistoryMenuItems
local NotReadyCasts

local function RefreshTest()
    if planner.testCast then
        planner.testCast.label:SetText(ns:IsTesting() and "Stop test" or "Test cast")
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Left: the boss's abilities, for every stage or one stage
------------------------------------------------------------------------------------------------------------------------

local function StageName(boss, stage)
    for _, info in ipairs(ns.bossStages[boss] or {}) do
        if ns:PhaseKey(info.stage) == stage then
            return info.name
        end
    end
    return "Stage " .. stage
end

local function HasStages(boss)
    return ns.bossStages[boss] ~= nil
end

local function IsIntermission(stage)
    local number = tonumber(stage)
    return number ~= nil and number ~= math.floor(number)
end

--A stage's name on its tab: 'Stage 2', or 'Intermission' for one between stages, numbered when the boss has more
local function ShortStageName(boss, stage)
    if IsIntermission(stage) then
        local count = 0
        for _, info in ipairs(ns.bossStages[boss] or {}) do
            if IsIntermission(ns:PhaseKey(info.stage)) then
                count = count + 1
            end
        end
        return count > 1 and ("Intermission " .. math.floor(tonumber(stage))) or "Intermission"
    end
    return "Stage " .. stage
end

--The selected stage tab: 'all' for every ability once, or one of the boss's stage keys
local function StageTab(boss)
    local tab = UI().stageTab
    if tab and tab ~= 'all' then
        for _, info in ipairs(ns.bossStages[boss] or {}) do
            if ns:PhaseKey(info.stage) == tab then
                return tab
            end
        end
    end
    return 'all'
end

--Which view the ability list shows: 'stage' lists the abilities of the stage tab, 'all' every ability once
local function AbilityView(boss)
    return StageTab(boss) == 'all' and 'all' or 'stage'
end

--The lines of the ability list: section labels { label } and abilities { ability, scope }, where scope is 'all' for
--assignments on every stage or a stage key for assignments on only that stage
local function AbilityListLines(boss, abilities, planText)
    local lines = {}
    if AbilityView(boss) == 'all' then
        local group
        for _, ability in ipairs(abilities) do
            if ability.group ~= group then
                group = ability.group
                if group then
                    table.insert(lines, { label = group })
                end
            end
            table.insert(lines, { ability = ability, scope = 'all' })
        end
        return lines
    end
    --An ability shows in the stages it happens in, and in stages the plan has lines for it
    local planned = {}
    for _, anchor in ipairs(ns:ParsePlan(planText).abilities) do
        if anchor.phases then
            for _, ability in ipairs(abilities) do
                local same = anchor.spellId and anchor.spellId == ability.spellId or
                    (not anchor.spellId and ability.name and anchor.name == ability.name:lower())
                if same then
                    local key = AbilityKey(ability)
                    planned[key] = planned[key] or {}
                    for phase in pairs(anchor.phases) do
                        planned[key][phase] = true
                    end
                end
            end
        end
    end
    local function InStage(ability, stage)
        for _, phase in ipairs(ability.phases or {}) do
            if ns:PhaseKey(phase) == stage then
                return true
            end
        end
        return planned[AbilityKey(ability)] and planned[AbilityKey(ability)][stage]
    end
    local stage = StageTab(boss)
    table.insert(lines, { label = StageName(boss, stage) })
    for _, ability in ipairs(abilities) do
        if InStage(ability, stage) then
            table.insert(lines, { ability = ability, scope = stage })
        end
    end
    local labelled = false
    for _, ability in ipairs(abilities) do
        if not ability.phases then
            if not labelled then
                table.insert(lines, { label = "Any stage" })
                labelled = true
            end
            table.insert(lines, { ability = ability, scope = 'all' })
        end
    end
    return lines
end

--The stages an ability happens in, on its row when nothing is assigned: '1, 3' or on a stage tab 'also 3'
local function StageHint(boss, line)
    local ability = line.ability
    if not HasStages(boss) or not ability.phases then
        return nil
    end
    local names = {}
    for _, phase in ipairs(ability.phases) do
        local key = ns:PhaseKey(phase)
        if key ~= line.scope then
            table.insert(names, IsIntermission(key) and "Int" or key)
        end
    end
    if #names == 0 then
        return nil
    end
    return (line.scope == 'all' and "" or "also ") .. table.concat(names, ", ")
end

--The selected line of the ability list, the first one when the selection isn't in the list
local function SelectedLine(lines)
    local ui = UI()
    local sameAbility
    for _, line in ipairs(lines) do
        if line.ability and AbilityKey(line.ability) == ui.ability then
            if line.scope == (ui.abilityScope or 'all') then
                return line
            end
            sameAbility = sameAbility or line
        end
    end
    local line = sameAbility
    if not line then
        for _, other in ipairs(lines) do
            if other.ability then
                line = other
                break
            end
        end
    end
    ui.ability = line and AbilityKey(line.ability)
    ui.abilityScope = line and line.scope
    return line
end

local function ScopeText(boss, scope)
    if scope == 'all' then
        return HasStages(boss) and "every stage" or nil
    end
    return StageName(boss, scope)
end

local function AbilityTooltip(tooltip, row)
    local ability = row.ability
    if not ability then
        return false
    end
    if ability.spellId and tooltip.SetSpellByID then
        tooltip:SetSpellByID(ability.spellId)
    else
        tooltip:SetText(ability.name or tostring(ability.spellId), 1, 1, 1)
    end
    tooltip:AddLine(" ")
    local _, _, boss = Selected()
    if ability.phases and HasStages(boss) then
        local names = {}
        for _, phase in ipairs(ability.phases) do
            table.insert(names, StageName(boss, ns:PhaseKey(phase)))
        end
        tooltip:AddLine("Happens in " .. table.concat(names, ", "), 0.7, 0.7, 0.7, true)
    elseif ability.group then
        tooltip:AddLine(ability.group, 0.7, 0.7, 0.7, true)
    end
    if ability.mythic then
        tooltip:AddLine("Mythic only", 1, 0.5, 0.25)
    end
    if ability.spellId then
        tooltip:AddLine("Spell id " .. ability.spellId, 0.5, 0.5, 0.5)
    end
    local assignments = ns:GetAbilityAssignments(GetPlanText(), ability)
    if #assignments > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Assigned", Accent())
        for _, assignment in ipairs(assignments) do
            local where = assignment.phases and (" in " .. StageName(boss, assignment.phases[1])) or ""
            tooltip:AddDoubleLine(assignment.entry, TimingText(assignment.before) .. " " .. CastsText(assignment) .. where, 1, 1, 1, 0.7, 0.7, 0.7)
        end
    else
        tooltip:AddLine("Click to assign a ramp, cooldown or trinket to it", 0.7, 0.7, 0.7)
    end
end

local function SetStageTab(tab)
    UI().stageTab = tab
    UI().abilityScope = tab
    Refresh()
end

local function StageChip(index)
    local chip = planner.stageTabs[index]
    if not chip then
        chip = ns:Chip(planner.tabsFrame, "", function(self) SetStageTab(self.value) end)
        ns:Tooltip(chip, function(tooltip, self)
            tooltip:SetText(self.title, 1, 1, 1)
            tooltip:AddLine(self.help, 0.7, 0.7, 0.7, true)
        end)
        planner.stageTabs[index] = chip
    end
    return chip
end

--A tab for every stage over the list, with the stage's full name in its tooltip. Returns false for a boss without stages
local function RefreshStageTabs(boss)
    for _, chip in ipairs(planner.stageTabs) do
        chip:Hide()
    end
    if not HasStages(boss) then
        planner.tabsFrame:Hide()
        return false
    end
    planner.tabsFrame:Show()
    local current = StageTab(boss)
    local tabs = { { value = 'all', text = "All stages", title = "All stages",
        help = "Every ability once. Assignments made here trigger in every stage." } }
    for _, info in ipairs(ns.bossStages[boss]) do
        local key = ns:PhaseKey(info.stage)
        table.insert(tabs, { value = key, text = ShortStageName(boss, key), title = info.name,
            help = "The abilities of this stage. Assignments made here only trigger in this stage." })
    end
    local x = 0
    for index, tab in ipairs(tabs) do
        local chip = StageChip(index)
        chip.value, chip.title, chip.help = tab.value, tab.title, tab.help
        chip:SetLabel(tab.text)
        chip:SetSelected(tab.value == current)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", x, 0)
        chip:Show()
        x = x + chip:GetWidth() + 6
    end
    return true
end

local function BuildList(page)
    planner.tabsFrame = CreateFrame("Frame", nil, page)
    planner.tabsFrame:SetPoint("TOPLEFT", 0, 0)
    planner.tabsFrame:SetPoint("TOPRIGHT", 0, 0)
    planner.tabsFrame:SetHeight(24)
    planner.stageTabs = {}

    local well = CreateFrame("Frame", nil, page)
    well:SetWidth(LIST_W)
    ns:Fill(well, theme.well)
    ns:Border(well, theme.border)
    planner.listWell = well
    local list = ns:ScrollList(well)
    list:SetPoint("TOPLEFT", 1, -4)
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
    row = ns:ListRow(planner.abilityList.content, ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.label:SetPoint("RIGHT", -62, 0)
    row.badge = ns:Text(row, 11, theme.text, "RIGHT")
    row.badge:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnClick", function(self)
        UI().ability = AbilityKey(self.ability)
        UI().abilityScope = self.scope
        Refresh()
    end)
    ns:Tooltip(row, AbilityTooltip)
    planner.abilityRows[index] = row
    return row
end

local function GroupLabel(index)
    local header = planner.groupLabels[index]
    if not header then
        header = ns:FoldHeader(planner.abilityList.content, 24)
        header:SetScript("OnClick", function(self)
            UI().foldedSections[self.key] = not self.folded or nil
            Refresh()
        end)
        planner.groupLabels[index] = header
    end
    return header
end

local function RefreshAbilities(lines, selected, planText)
    local _, _, boss = Selected()
    local list = planner.abilityList
    for _, row in ipairs(planner.abilityRows) do
        row:Hide()
    end
    for _, label in ipairs(planner.groupLabels) do
        label:Hide()
    end
    UI().foldedSections = UI().foldedSections or {}
    local y, rows, labels, folded, header = -2, 0, 0, false, nil
    for _, line in ipairs(lines) do
        if line.label then
            labels = labels + 1
            header = GroupLabel(labels)
            header.key = boss .. ':' .. AbilityView(boss) .. ':' .. line.label
            folded = UI().foldedSections[header.key] == true
            header:SetFolded(folded)
            header:SetHighlighted(false)
            header.label:SetText(line.label:upper())
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 0, y - 2)
            header:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
            header:Show()
            y = y - 26
        elseif folded then
            if line == selected then
                header:SetHighlighted(true)
            end
        else
            rows = rows + 1
            local row = AbilityRow(rows)
            row.ability, row.scope = line.ability, line.scope
            local name, icon = SpellNameAndIcon(line.ability.spellId, line.ability.name)
            row.label:SetText(name)
            row.icon:SetTexture(icon)
            --What triggers on this line: its own assignments, and on a stage line those for every stage too. Without
            --any, the other stages it happens in
            local count = #ns:GetAbilityAssignments(planText, line.ability, line.scope)
            if line.scope ~= 'all' then
                count = count + #ns:GetAbilityAssignments(planText, line.ability, 'all')
            end
            if count > 0 then
                row.badge:SetText(tostring(count))
                row.badge:SetTextColor(Accent())
            else
                row.badge:SetText(StageHint(boss, line) or '')
                row.badge:SetTextColor(1, 1, 1, 0.41)
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
            row:SetSelected(line == selected)
            row:Show()
            y = y - ROW_H
        end
    end
    list:SetContentHeight(-y + 4)
end

------------------------------------------------------------------------------------------------------------------------
-- Right: assignments of the selected ability, as cards that read like a sentence:
-- [icon] What to cast  ·  Lands [-] 3 [+] sec before  [Every cast]
------------------------------------------------------------------------------------------------------------------------

local CARD_H = 104
local OTHER = {}

local CASTS_HELP = "BigWigs and DBM number each cast of an ability in a fight: the bar shows 'Spectral Coils (2)' before " ..
    "the second one. Pick which of those numbers this is for. With Pick casts, list them like 2,4 or write a pattern " ..
    "like every 4 from 2 (casts 2, 6, 10...).\n\nThe count can start over in a new stage, the same way the boss mod's does."
local BEFORE_HELP = "How many seconds before the ability goes off your ramp or spell should land: the last step of a ramp, " ..
    "or the cast of a spell. The earlier steps of the ramp show before that, as far ahead as the ramp says, so the first " ..
    "message comes in time to start it.\n\nA negative number lands after the ability."

local CAST_CHOICES = {
    { text = "All casts", numbers = "1, 2, 3, 4..." },
    { text = "Odd casts", numbers = "1, 3, 5, 7...", every = 2, from = 1 },
    { text = "Even casts", numbers = "2, 4, 6, 8...", every = 2, from = 2 },
    { text = "Every 3rd from the 1st", numbers = "1, 4, 7, 10...", every = 3, from = 1 },
    { text = "Every 3rd from the 2nd", numbers = "2, 5, 8, 11...", every = 3, from = 2 },
    { text = "Every 3rd from the 3rd", numbers = "3, 6, 9, 12...", every = 3, from = 3 },
    { text = "Only the 1st cast", numbers = "1", casts = { 1 } },
    { text = "Pick casts...", numbers = "like 2, 4 or every 4 from 2", custom = true }
}

--Sets which casts an assignment is for from text: '2,4', 'every 2', 'every 3 from 2' or empty for all. Returns false
--when the text can't be read
local function SetCasts(assignment, text)
    text = (text or ''):lower()
    local everyText = text:match('^%s*every%s+(.-)%s*$')
    if everyText then
        local every, from = ns:ParseEvery(everyText)
        if not every then
            return false
        end
        assignment.casts, assignment.every, assignment.from = nil, every > 1 and every or nil, every > 1 and from or nil
        return true
    end
    local casts = {}
    for number in text:gmatch('%d+') do
        table.insert(casts, tonumber(number))
    end
    table.sort(casts)
    assignment.casts, assignment.every, assignment.from = #casts > 0 and casts or nil, nil, nil
    return true
end

--True when the casts of an assignment aren't one of the plain choices, so the box to write them shows
local function IsCustomCasts(assignment)
    if assignment.casts then
        return not (#assignment.casts == 1 and assignment.casts[1] == 1)
    end
    if not assignment.every then
        return false
    end
    for _, choice in ipairs(CAST_CHOICES) do
        if choice.every == assignment.every and choice.from == (assignment.from or 1) then
            return false
        end
    end
    return true
end

--Assignment cards are used here and on the Timeline page. A card edits one assignment of a group { ability, scope,
--assignments }: the assignments of an ability for one stage or for every stage, which are saved together
local function SaveGroup(group)
    if group.ability then
        local specKey, diffSlug, boss = Selected()
        ns:BackupPlan(specKey, diffSlug, boss, "Before editing assignments", 600)
        SetPlanText(ns:SetAbilityAssignments(GetPlanText(), boss, group.ability, group.assignments, group.scope))
    end
end

--The cards of a scroll list. refresh(keepRows) redraws the page they are on, keeping assignments that aren't saved yet
local function NewCardList(content, refresh)
    return { content = content, cards = {}, refresh = refresh }
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
    table.insert(items, { text = "Trinkets", header = true })
    for _, trinket in ipairs(ns:GetEquippedTrinkets()) do
        if trinket.spellId and trinket.name then
            table.insert(items, { text = trinket.name, value = trinket.name, icon = trinket.icon })
        end
    end
    for index, slot in ipairs({ "top", "bottom" }) do
        table.insert(items, { text = "Trinket " .. index .. " (" .. slot .. " slot, whatever is equipped)", value = "Trinket " .. index, icon = GetInventoryItemTexture("player", 12 + index) })
    end
    table.insert(items, { text = "Other", header = true })
    table.insert(items, { text = "Type a spell or item...", value = OTHER })
    return items
end

--The icon of a ramp's spell, or of the spell or trinket
local function EntryIcon(entry)
    if not entry or not entry:find('%S') then
        return QUESTION_MARK
    end
    local ramp = ns:FindRamp(ns:SelectedSpec(), entry)
    if ramp then
        local _, icon = SpellNameAndIcon(ramp.spellId or entry)
        return icon
    end
    local steps = ns:GetEntrySteps(ns:SelectedSpec(), entry)
    return steps and steps[#steps] and steps[#steps].icon or QUESTION_MARK
end

local function OpenEntryMenu(card)
    ns:OpenMenu(card.pick, EntryMenuItems(ns:SelectedSpec()), function(value)
        if value == OTHER then
            card.typing = true
            card.list.refresh(true)
            card.entryBox:SetFocus()
            return
        end
        card.assignment.entry = value
        SaveGroup(card.group)
        card.list.refresh(true)
    end)
end

local function Capitalized(text)
    return (text:gsub('^%l', string.upper))
end

local function AssignmentCard(list, index)
    local card = list.cards[index]
    if card then
        return card
    end
    card = CreateFrame("Frame", nil, list.content)
    card.list = list
    card:SetHeight(CARD_H - 8)
    ns:Fill(card, { 1, 1, 1, 0.03 })
    card.setBorder = ns:Border(card, theme.border)
    local function Save()
        SaveGroup(card.group)
        list.refresh(true)
    end

    --What: the ramp, spell or trinket
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(28, 28)
    card.icon:SetPoint("TOPLEFT", 8, -8)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.delete = ns:Button(card, "x", 24, 24, function()
        for slot, assignment in ipairs(card.group.assignments) do
            if assignment == card.assignment then
                table.remove(card.group.assignments, slot)
                break
            end
        end
        Save()
    end)
    card.delete:SetPoint("TOPRIGHT", -8, -10)
    ns:Tooltip(card.delete, "Remove this assignment")
    card.pick = ns:Dropdown(card, 300, 28, function() return card.assignment and card.assignment.entry or '' end,
        function() return {} end, function() end)
    card.pick:SetScript("OnClick", function() OpenEntryMenu(card) end)
    card.pick:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
    card.pick:SetPoint("RIGHT", card.delete, "LEFT", -8, 0)
    card.pick.placeholder = ns:Text(card.pick, 12, theme.section)
    card.pick.placeholder:SetPoint("LEFT", 10, 0)
    card.pick.placeholder:SetText("Choose what to cast...")
    ns:Tooltip(card.pick, "What to cast", "A ramp from the Ramps page, one of your cooldowns, a trinket, or any spell or item you type.")
    card.entryBox = ns:EditBox(card, 300, 28, function(text)
        card.assignment.entry = text:match('^%s*(.-)%s*$')
        card.typing = false
        Save()
    end)
    card.entryBox:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
    card.entryBox:SetPoint("RIGHT", card.delete, "LEFT", -8, 0)
    card.entryBox:SetPlaceholder("spell name, item name or item:id")
    card.entryBox:HookScript("OnEditFocusLost", function()
        if card.typing then
            card.typing = false
            list.refresh(true)
        end
    end)

    --When: seconds before the ability, and which casts
    local lands = ns:Text(card, 11, theme.dim)
    lands:SetPoint("TOPLEFT", 8, -50)
    lands:SetText("Lands")
    local function Adjust(delta)
        return function()
            card.assignment.before = (card.assignment.before or 0) + delta
            Save()
        end
    end
    card.minus = ns:Button(card, "-", 22, 24, Adjust(-1))
    card.minus:SetPoint("LEFT", lands, "RIGHT", 8, 0)
    card.before = ns:EditBox(card, 40, 24, function(text)
        card.assignment.before = tonumber(text) or 0
        Save()
    end)
    card.before:SetJustifyH("CENTER")
    card.before:SetTextInsets(2, 2, 0, 0)
    card.before:SetPoint("LEFT", card.minus, "RIGHT", 2, 0)
    card.plus = ns:Button(card, "+", 22, 24, Adjust(1))
    card.plus:SetPoint("LEFT", card.before, "RIGHT", 2, 0)
    card.beforeText = ns:Text(card, 11, theme.dim)
    card.beforeText:SetPoint("LEFT", card.plus, "RIGHT", 6, 0)
    card.beforeText:SetText("sec before")
    ns:Tooltip(card.before, "Seconds before", BEFORE_HELP)
    card.casts = ns:Dropdown(card, 150, 24, function() return card.assignment and Capitalized(CastsText(card.assignment)) or '' end,
        function()
            local items = {}
            for index, choice in ipairs(CAST_CHOICES) do
                table.insert(items, { text = choice.text .. "  |cff8a8a8a" .. choice.numbers .. "|r", value = index })
            end
            return items
        end, function(index)
            local choice = CAST_CHOICES[index]
            if choice.custom then
                card.customCasts = true
                list.refresh(true)
                card.castsBox:SetFocus()
                return
            end
            card.customCasts = false
            card.assignment.casts, card.assignment.every, card.assignment.from = choice.casts, choice.every, choice.every and choice.from or nil
            Save()
        end)
    card.casts:SetPoint("LEFT", card.beforeText, "RIGHT", 8, 0)
    ns:Tooltip(card.casts, "Which casts", CASTS_HELP)
    card.castsBox = ns:EditBox(card, 54, 24, function(text)
        if SetCasts(card.assignment, text) then
            SaveGroup(card.group)
        end
        list.refresh(true)
    end)
    card.castsBox:SetPoint("LEFT", card.casts, "RIGHT", 6, 0)
    card.castsBox:SetPlaceholder("2,4")
    ns:Tooltip(card.castsBox, "Which casts", CASTS_HELP)

    --What it does, in words, with every message in the tooltip
    card.noteFrame = CreateFrame("Frame", nil, card)
    card.noteFrame:SetPoint("TOPLEFT", 8, -78)
    card.noteFrame:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.noteFrame:SetHeight(14)
    card.noteFrame:EnableMouse(true)
    card.note = ns:Text(card.noteFrame, 10, theme.dim)
    card.note:SetPoint("LEFT")
    card.note:SetPoint("RIGHT")
    ns:Tooltip(card.noteFrame, function(tooltip)
        local timeline, append = list.timeline, false
        for _, use in ipairs(timeline and timeline.uses or {}) do
            if use.conflict and use.entry == card.assignment.entry then
                ConflictTooltip(tooltip, { use = use })
                tooltip:AddLine(" ")
                append = true
                break
            end
        end
        return AssignmentTooltip(tooltip, card.assignment, append)
    end)
    list.cards[index] = card
    return card
end

--Forgets a list's half done cards: a ramp or spell being typed, casts being picked
local function ResetCards(list)
    for _, card in ipairs(list.cards) do
        card.typing, card.customCasts = false, false
    end
end

--Shows a card for each item { group, assignment, ability, scope, note } from y down in the list, and returns where the
--cards end. note replaces the card's description, list.timeline (a recorded pull) finds casts it won't be ready for
local function FillCards(list, items, y)
    y = y or 0
    for _, card in ipairs(list.cards) do
        card:Hide()
    end
    for index, item in ipairs(items) do
        local card = AssignmentCard(list, index)
        local assignment = item.assignment
        card.group, card.assignment = item.group, assignment
        local hasEntry = assignment.entry and assignment.entry:find('%S')
        card.pick:Refresh()
        card.pick.placeholder:SetShown(not hasEntry)
        card.pick:SetShown(not card.typing)
        card.entryBox:SetShown(card.typing == true)
        if card.typing then
            card.entryBox:SetValue(assignment.entry or '')
        end
        card.icon:SetTexture(EntryIcon(assignment.entry))
        card.before:SetValue(tostring(assignment.before or 0))
        card.casts:Refresh()
        local custom = card.customCasts or IsCustomCasts(assignment)
        card.castsBox:SetShown(custom)
        card.castsBox:SetValue(CastsBoxText(assignment))
        local text, isError = DescribeAssignment(assignment)
        local notReady = not isError and NotReadyCasts(assignment, item.ability, item.scope, list.timeline)
        if notReady then
            text, isError = "Not ready in time on " .. notReady .. "  ·  see the Timeline", true
        elseif item.note and not isError then
            text = item.note
        end
        card.note:SetText(text)
        if isError then
            card.note:SetTextColor(ErrorColor())
            card.setBorder(ErrorColor(0.35))
        else
            card.note:SetTextColor(1, 1, 1, 0.53)
            card.setBorder(1, 1, 1, 0.06)
        end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 0, -y)
        card:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
        card:Show()
        y = y + CARD_H
    end
    return y
end

local function TestCast()
    if ns:IsTesting() then
        ns:StopTest()
        return
    end
    if not planner.ability then
        return
    end
    local specKey, diffSlug, boss = Selected()
    local count = tonumber(planner.testCount:GetText()) or 1
    local seconds = tonumber(planner.testSeconds:GetText()) or 15
    UI().testSeconds = seconds
    ns:StartTest(specKey, diffSlug, boss, { ability = planner.ability, count = count, seconds = seconds,
        phase = planner.scope ~= 'all' and planner.scope or nil })
end

local function AddAssignment()
    if not planner.ability then
        return
    end
    UI().plannerTab = 'assignments'
    table.insert(planner.assignments, { before = 0, entry = '' })
    Refresh(true)
    local card = planner.cards[#planner.assignments]
    if card then
        OpenEntryMenu(card)
    end
end

local function BuildAssignmentsTab(panel)
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetAllPoints()
    planner.assignmentsTab = tab

    planner.abilityIcon = tab:CreateTexture(nil, "ARTWORK")
    planner.abilityIcon:SetSize(40, 40)
    planner.abilityIcon:SetPoint("TOPLEFT", 0, 0)
    planner.abilityIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    planner.abilityName = ns:Text(tab, 18)
    planner.abilityName:SetPoint("TOPLEFT", planner.abilityIcon, "TOPRIGHT", 12, -2)
    planner.abilityName:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.abilityInfo = ns:Text(tab, 11, theme.dim)
    planner.abilityInfo:SetPoint("BOTTOMLEFT", planner.abilityIcon, "BOTTOMRIGHT", 12, 2)
    planner.abilityInfo:SetPoint("RIGHT", tab, "RIGHT", 0, 0)

    --On a stage, what is assigned for every stage triggers too
    planner.alsoAll = CreateFrame("Button", nil, tab)
    planner.alsoAll:SetPoint("TOPLEFT", 0, -50)
    planner.alsoAll:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.alsoAll:SetHeight(16)
    planner.alsoAll.label = ns:Text(planner.alsoAll, 10, theme.dim)
    planner.alsoAll.label:SetPoint("LEFT")
    planner.alsoAll.label:SetPoint("RIGHT")
    planner.alsoAll:SetScript("OnClick", function()
        UI().stageTab = 'all'
        UI().abilityScope = 'all'
        Refresh()
    end)
    ns:Tooltip(planner.alsoAll, "Assigned for every stage", "These trigger in every stage this ability happens in. Click to edit them on the All stages tab.")

    local list = ns:ScrollList(tab)
    list:SetPoint("TOPLEFT", 0, -72)
    list:SetPoint("BOTTOMRIGHT", 0, 62)
    planner.assignmentList = list
    planner.cardList = NewCardList(list.content, function(keepRows) Refresh(keepRows) end)
    planner.cards = planner.cardList.cards

    planner.empty = ns:Text(list.content, 12, theme.dim)
    planner.empty:SetPoint("TOPLEFT", 0, -4)
    planner.empty:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
    planner.empty:SetWordWrap(true)
    planner.empty:SetJustifyV("TOP")
    planner.empty:SetHeight(64)

    --Testing one cast of the ability
    local rule = tab:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 54)
    rule:SetPoint("BOTTOMRIGHT", 0, 54)
    rule:SetColorTexture(1, 1, 1, 0.06)
    local testLabel = ns:SectionLabel(tab, "Test cast")
    testLabel:SetPoint("BOTTOMLEFT", 0, 36)
    local castText = ns:Text(tab, 11, theme.dim)
    castText:SetPoint("BOTTOMLEFT", 0, 6)
    castText:SetText("Cast")
    planner.testCount = ns:EditBox(tab, 40, 24)
    planner.testCount:SetPoint("LEFT", castText, "RIGHT", 6, 0)
    local inText = ns:Text(tab, 11, theme.dim)
    inText:SetPoint("LEFT", planner.testCount, "RIGHT", 8, 0)
    inText:SetText("goes off in")
    planner.testSeconds = ns:EditBox(tab, 44, 24)
    planner.testSeconds:SetPoint("LEFT", inText, "RIGHT", 6, 0)
    local secondsText = ns:Text(tab, 11, theme.dim)
    secondsText:SetPoint("LEFT", planner.testSeconds, "RIGHT", 6, 0)
    secondsText:SetText("seconds")
    planner.testCast = ns:Button(tab, "Test cast", 110, 26, TestCast, true)
    planner.testCast:SetPoint("BOTTOMRIGHT", 0, 4)
    ns:Tooltip(planner.testCast, "Test cast",
        "Pretends your boss mod shows a bar for this cast of the ability, and shows the reminders of its assignments as they " ..
        "would come. Other lines of the plan are left out.")
end

--Why a use of a spell won't be ready, in the tooltip of its reminder
function ConflictTooltip(tooltip, reminder)
    local use, conflict = reminder.use, reminder.use.conflict
    tooltip:SetText("Not ready in time", theme.error[1], theme.error[2], theme.error[3])
    tooltip:AddLine(use.entry .. " is used at " .. ns:FormatTime(use.at) .. ", but it is only back at " ..
        ns:FormatTime(conflict.readyAt) .. ".", 1, 1, 1, true)
    local cooldown = conflict.cooldown
    tooltip:AddLine("Cooldown " .. ns:FormatTime(cooldown.duration) .. (cooldown.charges > 1 and (", " .. cooldown.charges .. " charges") or "") ..
        (cooldown.seen and "" or ", the spell's base cooldown: cast it once out of combat so the addon knows yours with your talents"), 0.7, 0.7, 0.7, true)
end

------------------------------------------------------------------------------------------------------------------------
-- Right: plan text and MRT note
------------------------------------------------------------------------------------------------------------------------

--Where the plan can be copied to: the other difficulty of the boss, and the other bosses of its raid on this difficulty
function CopyMenuItems()
    local _, _, boss = Selected()
    local difficulty = UI().difficulty
    local other = difficulty == 15 and 16 or 15
    local items = { { text = ns.bosses[boss].name, header = true },
        { text = ns.difficulties[other].name, value = { encounterId = boss, difficulty = other } } }
    for _, raid in ipairs(ns.raids) do
        if raid.name == ns.bosses[boss].raid and #raid.bosses > 1 then
            table.insert(items, { text = raid.name .. ", " .. ns.difficulties[difficulty].name, header = true })
            for _, raidBoss in ipairs(raid.bosses) do
                if raidBoss.encounterId ~= boss then
                    table.insert(items, { text = raidBoss.name, value = { encounterId = raidBoss.encounterId, difficulty = difficulty } })
                end
            end
        end
    end
    return items
end

--Copies the saved plan to another boss or difficulty, keeping what was there to undo
function CopyPlanTo(target)
    local specKey, _, boss = Selected()
    local diffSlug = ns.difficulties[target.difficulty].slug
    local name = ns.bosses[target.encounterId].name .. " " .. ns.difficulties[target.difficulty].name
    local text = GetPlanText()
    if not text:find('%S') then
        planner.planStatus:SetText("There is no saved plan to copy")
        planner.planStatus:SetTextColor(ErrorColor())
        return
    end
    local old = ns:GetPlan(specKey, diffSlug, target.encounterId)
    ns:BackupPlan(specKey, diffSlug, target.encounterId, "Before a copy over it")
    ns:SetPlan(specKey, diffSlug, target.encounterId, text)
    planner.copyUndo = old:find('%S') and { specKey = specKey, diffSlug = diffSlug, encounterId = target.encounterId, text = old, name = name } or nil
    Refresh()
    local status = "Copied to " .. name .. (planner.copyUndo and ", its plan was replaced" or "")
    if target.encounterId ~= boss and ns:ParsePlan(text).abilities[1] then
        status = status .. ". Its @ lines are for " .. ns.bosses[boss].name .. "'s abilities"
    end
    planner.planStatus:SetText(status)
    planner.planStatus:SetTextColor(Accent())
end

--Earlier versions of the plan to restore, newest first
function HistoryMenuItems()
    local specKey, diffSlug, boss = Selected()
    local history = ns:GetPlanHistory(specKey, diffSlug, boss)
    local items = { { text = "Restore an earlier version", header = true } }
    for _, version in ipairs(history) do
        local lines = select(2, version.text:gsub('\n', '')) + 1
        table.insert(items, { text = date("%d %b %H:%M", version.time) .. "  |cff8a8a8a" .. version.reason .. ", " .. lines ..
            (lines == 1 and " line" or " lines") .. "|r", value = version })
    end
    if #history == 0 then
        table.insert(items, { text = "No earlier versions yet", header = true })
    end
    return items
end

local function BuildPlanTextTab(panel)
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetAllPoints()
    planner.planTextTab = tab
    local area = ns:TextArea(tab, function()
        planner.planStatus:SetText("Not saved yet")
        planner.planStatus:SetTextColor(1, 1, 1, 0.53)
    end)
    area:SetPoint("TOPLEFT", 0, 0)
    area:SetPoint("BOTTOMRIGHT", 0, 100)
    planner.planBox = area.box

    planner.planSave = ns:Button(tab, "Save", 90, 26, function()
        local text = planner.planBox:GetText()
        local result = ns:CheckPlan(text)
        if result == true then
            local specKey, diffSlug, boss = Selected()
            if text ~= GetPlanText() then
                ns:BackupPlan(specKey, diffSlug, boss, "Before editing the plan text")
            end
            SetPlanText(text)
            planner.planBox:ClearFocus()
            Refresh()
            planner.planStatus:SetText("Saved")
            planner.planStatus:SetTextColor(Accent())
        else
            planner.planStatus:SetText(result)
            planner.planStatus:SetTextColor(ErrorColor())
        end
    end, true)
    planner.planSave:SetPoint("BOTTOMLEFT", 0, 66)
    planner.planCopy = ns:Dropdown(tab, 120, 26, function() return "Copy to..." end, CopyMenuItems, CopyPlanTo)
    planner.planCopy:SetPoint("LEFT", planner.planSave, "RIGHT", 8, 0)
    ns:Tooltip(planner.planCopy, "Copy this plan", "Copies the saved plan to the other difficulty of this boss, or to another boss of the raid. " ..
        "A plan that is there already is replaced, and Undo brings it back.")
    planner.planUndo = ns:Button(tab, "Undo", 70, 26, function()
        local undo = planner.copyUndo
        if undo then
            ns:SetPlan(undo.specKey, undo.diffSlug, undo.encounterId, undo.text)
            planner.copyUndo = nil
            Refresh()
            planner.planStatus:SetText("Put back the plan of " .. undo.name)
            planner.planStatus:SetTextColor(1, 1, 1, 0.53)
        end
    end)
    planner.planHistory = ns:Dropdown(tab, 100, 26, function() return "History" end, HistoryMenuItems, function(version)
        local specKey, diffSlug, boss = Selected()
        ns:RestorePlan(specKey, diffSlug, boss, version)
        planner.copyUndo = nil
        Refresh()
        planner.planStatus:SetText("Restored the version from " .. date("%d %b %H:%M", version.time) .. ", the plan before is in History")
        planner.planStatus:SetTextColor(Accent())
    end)
    planner.planHistory:SetPoint("LEFT", planner.planCopy, "RIGHT", 8, 0)
    ns:Tooltip(planner.planHistory, "History", "Earlier versions of this plan, kept before an import, a copy over it, taking times from a note, " ..
        "saving the plan text and editing assignments (one every ten minutes). Pick one to put it back.")
    planner.planUndo:SetPoint("LEFT", planner.planHistory, "RIGHT", 8, 0)
    planner.planStatus = ns:Text(tab, 11, theme.dim)
    planner.planStatus:SetPoint("BOTTOMLEFT", 0, 44)
    planner.planStatus:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    local help = ns:Text(tab, 10, theme.dim)
    help:SetPoint("BOTTOMLEFT", 0, 0)
    help:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    help:SetHeight(34)
    help:SetWordWrap(true)
    help:SetJustifyV("BOTTOM")
    help:SetText("One line per timing: 01:25 - Evangelism after the pull, 00:50 p2 - Rewind after stage 2 starts, " ..
        "@Spectral Coils p2 #2 -3 - Power Word: Barrier for boss abilities (p2 only in stage 2). Lines starting with -- are notes.")
end

--The plans a Crescendo string exports: the selected plan, or every boss of its raid on both difficulties
local function PlansToExport()
    local _, diffSlug, boss = Selected()
    if UI().shareScope ~= 'raid' then
        return { { encounterId = boss, diffSlug = diffSlug } }
    end
    local plans = {}
    for _, raid in ipairs(ns.raids) do
        if raid.name == ns.bosses[boss].raid then
            for _, raidBoss in ipairs(raid.bosses) do
                for _, diffId in ipairs({ 15, 16 }) do
                    table.insert(plans, { encounterId = raidBoss.encounterId, diffSlug = ns.difficulties[diffId].slug })
                end
            end
        end
    end
    return plans
end

local function ShareStatus(text, color)
    planner.noteStatus:SetText(text)
    if color == 'error' then
        planner.noteStatus:SetTextColor(ErrorColor())
    elseif color == 'accent' then
        planner.noteStatus:SetTextColor(Accent())
    else
        planner.noteStatus:SetTextColor(1, 1, 1, 0.53)
    end
end

--Reads what is pasted in Crescendo mode and says what importing it does
local function CheckShareText()
    local text = planner.noteBox:GetText() or ''
    planner.shareData = nil
    if not text:find('%S') then
        ShareStatus("Paste a plan string from another player here, or export yours.")
    else
        local data, problem = ns:ReadPlanString(text)
        planner.shareData = data
        if data then
            ShareStatus("Ready to import " .. ns:DescribePlanImport(data), 'accent')
        else
            ShareStatus(problem, 'error')
        end
    end
    planner.shareImport:SetAlpha(planner.shareData and 1 or 0.4)
    planner.shareImport:SetEnabled(planner.shareData ~= nil)
end

local function BuildNoteTab(panel)
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetAllPoints()
    planner.noteTab = tab
    planner.shareMode = ns:Segmented(tab, {
        { text = "Crescendo string", value = 'crescendo', tooltip = "Share plans with other Crescendo users, with the ramps they use." },
        { text = "MRT note", value = 'mrt', tooltip = "Take your times from an MRT note, or copy the plan out as note lines." }
    }, 240, 24, function() return UI().shareMode == 'mrt' and 'mrt' or 'crescendo' end, function(mode)
        UI().shareMode = mode
        planner.noteBox:SetText('')
        Refresh()
    end)
    planner.shareMode:SetPoint("TOPLEFT", 0, 0)
    planner.noteIntro = ns:Text(tab, 11, theme.dim)
    planner.noteIntro:SetPoint("TOPLEFT", 0, -32)
    planner.noteIntro:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.noteIntro:SetWordWrap(true)
    local area = ns:TextArea(tab, function(text)
        if UI().shareMode == 'mrt' then
            UI().note = text
        else
            CheckShareText()
        end
    end)
    area:SetPoint("TOPLEFT", 0, -66)
    area:SetPoint("BOTTOMRIGHT", 0, 76)
    planner.noteBox = area.box

    --Crescendo strings
    planner.shareButtons = CreateFrame("Frame", nil, tab)
    planner.shareButtons:SetPoint("BOTTOMLEFT", 0, 42)
    planner.shareButtons:SetPoint("BOTTOMRIGHT", 0, 42)
    planner.shareButtons:SetHeight(26)
    planner.shareScope = ns:Segmented(planner.shareButtons, {
        { text = "This plan", value = 'plan', tooltip = "The plan of the selected boss and difficulty." },
        { text = "Whole raid", value = 'raid', tooltip = "The plans of every boss of this raid, on Heroic and Mythic." }
    }, 170, 26, function() return UI().shareScope == 'raid' and 'raid' or 'plan' end, function(scope) UI().shareScope = scope end)
    planner.shareScope:SetPoint("LEFT", 0, 0)
    planner.shareExport = ns:Button(planner.shareButtons, "Export", 80, 26, function()
        local specKey = Selected()
        local text, count = ns:ExportPlans(specKey, PlansToExport())
        if not text then
            ShareStatus("There is no plan to export yet", 'error')
            return
        end
        planner.noteBox:SetText(text)
        planner.noteBox:SetFocus()
        planner.noteBox:HighlightText()
        planner.shareData = nil
        planner.shareImport:SetAlpha(0.4)
        planner.shareImport:SetEnabled(false)
        ShareStatus(count .. (count == 1 and " plan" or " plans") .. " ready, press Ctrl+C to copy and send it", 'accent')
    end, true)
    planner.shareExport:SetPoint("LEFT", planner.shareScope, "RIGHT", 8, 0)
    planner.shareImport = ns:ConfirmButton(planner.shareButtons, "Import", "Click to confirm", 130, 26, function()
        if planner.shareData then
            ns:ImportPlans(planner.shareData)
            local text = "Imported " .. ns:DescribePlanImport(planner.shareData):gsub(", replaces yours", "")
            planner.noteBox:SetText('')
            planner.shareData = nil
            Refresh()
            ShareStatus(text, 'accent')
        end
    end)
    planner.shareImport:SetPoint("LEFT", planner.shareExport, "RIGHT", 8, 0)
    ns:Tooltip(planner.shareImport, "Import", "Replaces your plans for the bosses in the string, and adds the ramps in it you don't have. Your own ramps with the same name are kept.")

    --MRT notes
    planner.noteButtons = CreateFrame("Frame", nil, tab)
    planner.noteButtons:SetPoint("BOTTOMLEFT", 0, 42)
    planner.noteButtons:SetPoint("BOTTOMRIGHT", 0, 42)
    planner.noteButtons:SetHeight(26)
    planner.noteImport = ns:ConfirmButton(planner.noteButtons, "Use times from note", "Click again to replace", 170, 26, function()
        local specKey, diffSlug, boss = Selected()
        ns:ImportNoteIntoPlan(specKey, diffSlug, boss, planner.noteBox:GetText())
        Refresh()
        ShareStatus("The plan's times now come from the note", 'accent')
    end)
    planner.noteImport:SetPoint("LEFT", 0, 0)
    planner.noteExport = ns:Button(planner.noteButtons, "Copy plan as note", 150, 26, function()
        local specKey = Selected()
        local note = ns:PlanToNote(GetPlanText(), specKey)
        UI().note = note
        planner.noteBox:SetText(note)
        planner.noteBox:SetFocus()
        planner.noteBox:HighlightText()
        ShareStatus("Press Ctrl+C to copy")
    end)
    planner.noteExport:SetPoint("LEFT", planner.noteImport, "RIGHT", 8, 0)
    planner.noteStatus = ns:Text(tab, 11, theme.dim)
    planner.noteStatus:SetPoint("BOTTOMLEFT", 0, 0)
    planner.noteStatus:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.noteStatus:SetHeight(34)
    planner.noteStatus:SetWordWrap(true)
    planner.noteStatus:SetJustifyV("TOP")
end

local function RefreshShare()
    local mrt = UI().shareMode == 'mrt'
    planner.shareMode:Refresh()
    planner.shareScope:Refresh()
    planner.shareButtons:SetShown(not mrt)
    planner.noteButtons:SetShown(mrt)
    if mrt then
        planner.noteIntro:SetText("Paste an MRT note to take your times from it, or copy this plan out as note lines. Boss ability lines stay in the plan.")
        if not planner.noteBox:HasFocus() then
            planner.noteBox:SetText(UI().note or '')
        end
        ShareStatus("")
    else
        planner.noteIntro:SetText("Send your plans to another Crescendo user: export, copy and paste it anywhere. To import, paste a string from someone here.")
        CheckShareText()
    end
end

--Plan text and Share open in place of the assignments, from the buttons under them, and close with another click
local function PanelButton(parent, label, width, key)
    local button = ns:Button(parent, label, width, 28, function()
        UI().plannerTab = UI().plannerTab == key and 'assignments' or key
        Refresh()
    end)
    button.underline = button:CreateTexture(nil, "OVERLAY")
    button.underline:SetHeight(2)
    button.underline:SetPoint("BOTTOMLEFT", 1, 1)
    button.underline:SetPoint("BOTTOMRIGHT", -1, 1)
    button.key = key
    return button
end

local function BuildRight(page)
    local right = CreateFrame("Frame", nil, page)
    planner.right = right
    local panel = CreateFrame("Frame", nil, right)
    panel:SetPoint("TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", 0, BOTTOM_H)
    BuildAssignmentsTab(panel)
    BuildPlanTextTab(panel)
    BuildNoteTab(panel)

    local rule = right:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, BOTTOM_H - 6)
    rule:SetPoint("BOTTOMRIGHT", 0, BOTTOM_H - 6)
    rule:SetColorTexture(1, 1, 1, 0.06)
    planner.addButton = ns:Button(right, "+ Add assignment", 150, 28, AddAssignment, true)
    planner.addButton:SetPoint("BOTTOMLEFT", 0, 0)
    planner.timelineButton = ns:Button(right, "Timeline", 84, 28, function() ns:ShowPage('timeline') end)
    planner.timelineButton:SetPoint("BOTTOMRIGHT", 0, 0)
    ns:Tooltip(planner.timelineButton, "Timeline", "The recorded pull of this boss: every cast of its abilities and your reminders. Also in the bar on the left.")
    planner.shareButton = PanelButton(right, "Share", 74, 'note')
    planner.shareButton:SetPoint("RIGHT", planner.timelineButton, "LEFT", -8, 0)
    ns:Tooltip(planner.shareButton, "Share", "Send plans to other Crescendo users with a string, or take times from an MRT note.")
    planner.planButton = PanelButton(right, "Plan text", 90, 'plan')
    planner.planButton:SetPoint("RIGHT", planner.shareButton, "LEFT", -8, 0)
    ns:Tooltip(planner.planButton, "Plan text", "The whole plan of this boss as text, to edit, copy to another boss or restore from history.")
end

------------------------------------------------------------------------------------------------------------------------
-- Right: how the reminders look, what comes first in the pull and the ready check line
------------------------------------------------------------------------------------------------------------------------

local function PreviewIcon(parent, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return icon
end

local function BuildPreviews(page)
    local column = CreateFrame("Frame", nil, page)
    column:SetWidth(PREVIEW_W)
    planner.previews = column
    local edge = column:CreateTexture(nil, "BORDER")
    edge:SetWidth(1)
    edge:SetPoint("TOPLEFT", -16, 0)
    edge:SetPoint("BOTTOMLEFT", -16, 0)
    edge:SetColorTexture(1, 1, 1, 0.06)

    ns:SectionLabel(column, "Reminders · icon, bar, text"):SetPoint("TOPLEFT", 0, 0)
    planner.styleInUse = ns:Text(column, 10, theme.dim, "RIGHT")
    planner.styleInUse:SetPoint("TOPRIGHT", 0, 0)
    --Icon: the icon with a countdown on it, the text next to it
    local iconBox = CreateFrame("Frame", nil, column)
    iconBox:SetPoint("TOPLEFT", 0, -18)
    iconBox:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    iconBox:SetHeight(64)
    ns:Fill(iconBox, { 0.08, 0.07, 0.06, 1 })
    ns:Border(iconBox, theme.border)
    planner.previewIcon = PreviewIcon(iconBox, 44)
    planner.previewIcon:SetPoint("LEFT", 10, 0)
    local iconFrame = CreateFrame("Frame", nil, iconBox)
    iconFrame:SetAllPoints(planner.previewIcon)
    planner.previewIconBorder = ns:Border(iconFrame)
    planner.previewIconTime = iconFrame:CreateFontString(nil, "OVERLAY")
    planner.previewIconTime:SetFont(ns:GetFont(), 17, "OUTLINE")
    planner.previewIconTime:SetPoint("CENTER")
    planner.previewIconTime:SetText("2.3")
    planner.previewIconBar = iconFrame:CreateTexture(nil, "OVERLAY")
    planner.previewIconBar:SetHeight(3)
    planner.previewIconBar:SetPoint("BOTTOMLEFT")
    planner.previewIconBar:SetWidth(26)
    planner.previewIconText = ns:Text(iconBox, 13)
    planner.previewIconText:SetPoint("LEFT", planner.previewIcon, "RIGHT", 10, 0)
    planner.previewIconText:SetPoint("RIGHT", iconBox, "RIGHT", -8, 0)
    planner.previewIconText:SetWordWrap(true)
    --Bar: the icon, a bar that runs out, the text and the countdown
    local bar = CreateFrame("Frame", nil, column)
    bar:SetPoint("TOPLEFT", 0, -90)
    bar:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    bar:SetHeight(28)
    ns:Fill(bar, theme.window)
    ns:Border(bar, { 0, 0, 0, 1 })
    planner.previewBarIcon = PreviewIcon(bar, 28)
    planner.previewBarIcon:SetPoint("LEFT")
    planner.previewBarFill = bar:CreateTexture(nil, "ARTWORK")
    planner.previewBarFill:SetPoint("TOPLEFT", planner.previewBarIcon, "TOPRIGHT", 0, 0)
    planner.previewBarFill:SetPoint("BOTTOMLEFT", planner.previewBarIcon, "BOTTOMRIGHT", 0, 0)
    planner.previewBarFill:SetWidth(120)
    planner.previewBarTime = ns:Text(bar, 13, theme.text, "RIGHT")
    planner.previewBarTime:SetPoint("RIGHT", -8, 0)
    planner.previewBarTime:SetText("1.4")
    planner.previewBarText = ns:Text(bar, 12)
    planner.previewBarText:SetPoint("LEFT", planner.previewBarIcon, "RIGHT", 8, 0)
    planner.previewBarText:SetPoint("RIGHT", planner.previewBarTime, "LEFT", -6, 0)
    --Text: only the text, with the countdown after it
    planner.previewText = ns:Text(column, 16)
    planner.previewText:SetPoint("TOPLEFT", 0, -132)
    planner.previewText:SetPoint("RIGHT", column, "RIGHT", 0, 0)

    --Next up: the first presses of the recorded pull, or of the plan's times
    planner.nextUpLabel = ns:SectionLabel(column, "Next up")
    planner.nextUpLabel:SetPoint("TOPLEFT", 0, -172)
    planner.nextCards = {}
    local cardWidth = (PREVIEW_W - 12) / 3
    for index = 1, 3 do
        local card = CreateFrame("Frame", nil, column)
        card:SetSize(cardWidth, 84)
        card:SetPoint("TOPLEFT", (index - 1) * (cardWidth + 6), -190)
        ns:Fill(card, theme.window)
        card.top = card:CreateTexture(nil, "ARTWORK")
        card.top:SetHeight(2)
        card.top:SetPoint("TOPLEFT")
        card.top:SetPoint("TOPRIGHT")
        card.icon = PreviewIcon(card, 26)
        card.icon:SetPoint("TOP", 0, -10)
        card.time = ns:Text(card, 15, theme.text, "CENTER")
        card.time:SetPoint("TOP", card.icon, "BOTTOM", 0, -5)
        card.name = ns:Text(card, 10, theme.dim, "CENTER")
        card.name:SetPoint("TOPLEFT", 4, -62)
        card.name:SetPoint("RIGHT", card, "RIGHT", -4, 0)
        planner.nextCards[index] = card
    end
    planner.nextEmpty = ns:Text(column, 11, theme.dim)
    planner.nextEmpty:SetPoint("TOPLEFT", 0, -192)
    planner.nextEmpty:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    planner.nextEmpty:SetWordWrap(true)
    planner.nextEmpty:SetText("Nothing in the plan yet.")

    --The ready check line for this boss
    ns:SectionLabel(column, "Ready check"):SetPoint("TOPLEFT", 0, -290)
    local check = CreateFrame("Frame", nil, column)
    check:SetPoint("TOPLEFT", 0, -308)
    check:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    check:SetHeight(110)
    ns:Fill(check, { 0, 0, 0, 0.35 })
    ns:Border(check, theme.border)
    planner.readyCheck = ns:Text(check, 11)
    planner.readyCheck:SetPoint("TOPLEFT", 8, -8)
    planner.readyCheck:SetPoint("BOTTOMRIGHT", -8, 8)
    planner.readyCheck:SetWordWrap(true)
    planner.readyCheck:SetJustifyV("TOP")
    local note = ns:Text(column, 10, theme.dim)
    note:SetPoint("BOTTOMLEFT", 0, 0)
    note:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    note:SetWordWrap(true)
    note:SetText("Style, size and how many Next up shows are set on the Display and General pages.")
end

--The first presses of the pull: when each use lands on the recorded pull, else the plan's times
local function FirstPresses(planText)
    local presses = {}
    local timeline = planner.cardTimeline
    if timeline then
        for _, use in ipairs(timeline.uses) do
            table.insert(presses, { entry = use.entry, at = use.at, conflict = use.conflict ~= nil })
        end
    else
        for _, timing in ipairs(ns:ParsePlan(planText).times) do
            if timing.phase == 'main' then
                table.insert(presses, { entry = timing.entry, at = timing.seconds })
            end
        end
    end
    table.sort(presses, function(a, b) return a.at < b.at end)
    return presses
end

local function RefreshPreviews(planText)
    local specKey, diffSlug, boss = Selected()
    local r, g, b = ns:GetAccent()
    local style = ns.db.options.displayStyle or 'icon'
    planner.styleInUse:SetText("in use: " .. Capitalized(style))
    --The messages of the selected ability's first assignment, or of the first press of the plan
    local presses = FirstPresses(planText)
    local entry = planner.assignments and planner.assignments[1] and planner.assignments[1].entry
    if not (entry and entry:find('%S')) then
        entry = presses[1] and presses[1].entry
    end
    local steps = entry and ns:GetEntrySteps(specKey, entry) or {}
    local first, last = steps[1], steps[#steps]
    planner.previewIcon:SetTexture(first and first.icon or QUESTION_MARK)
    planner.previewIconText:SetText(first and first.text or "Pick a ramp or spell to see it here")
    planner.previewIconBorder(r, g, b, 1)
    planner.previewIconBar:SetColorTexture(r, g, b, 1)
    planner.previewBarIcon:SetTexture(last and last.icon or QUESTION_MARK)
    planner.previewBarText:SetText(last and last.text or "Your press")
    planner.previewBarFill:SetColorTexture(r, g, b, 0.32)
    planner.previewText:SetText((last and last.text or "Your press") .. "  |cff" ..
        string.format("%02x%02x%02x", r * 255, g * 255, b * 255) .. "0.8|r")
    --Next up
    for index, card in ipairs(planner.nextCards) do
        local press = presses[index]
        card:SetShown(press ~= nil)
        if press then
            card.icon:SetTexture(EntryIcon(press.entry))
            card.time:SetText(ns:FormatTime(press.at))
            card.name:SetText(press.entry)
            card.top:SetColorTexture(r, g, b, index == 1 and 1 or 0.4)
            if index == 1 then
                card.time:SetTextColor(r, g, b, 1)
            else
                card.time:SetTextColor(1, 1, 1, 0.9)
            end
            card:SetAlpha(press.conflict and 0.55 or 1)
            if press.conflict then
                card.name:SetText(press.entry .. " · cd")
            end
        end
    end
    planner.nextEmpty:SetShown(#presses == 0)
    planner.nextUpLabel:SetText(planner.cardTimeline and "NEXT UP · ON THE RECORDED PULL" or "NEXT UP")
    --Ready check
    local lines = ns:ReadyCheckLines(boss, UI().difficulty, specKey)
    planner.readyCheck:SetText("|cff" .. string.format("%02x%02x%02x", r * 255, g * 255, b * 255) .. "Crescendo:|r " ..
        table.concat(lines or { "No plan" }, "\n"))
end

--The casts of an ability in a recorded pull's timeline on which an assignment's spell won't be ready, like 'cast 3 (02:10)'
function NotReadyCasts(assignment, ability, scope, timeline)
    if not timeline or not ability then
        return nil
    end
    local casts = {}
    for _, use in ipairs(timeline.uses) do
        local cast = use.cast
        if use.conflict and cast and use.entry == assignment.entry and (scope == 'all' or cast.stage == scope) and
            ((ability.spellId and cast.spellId == ability.spellId) or (ability.name and cast.name:lower() == ability.name:lower())) then
            table.insert(casts, (cast.count and ("cast " .. cast.count .. " ") or "") .. "(" .. ns:FormatTime(cast.at) .. ")")
        end
    end
    return #casts > 0 and table.concat(casts, ", ") or nil
end

local function RefreshAssignments(line, keepRows)
    local _, _, boss = Selected()
    local ability, scope = line and line.ability, line and line.scope or 'all'
    local same = planner.ability and ability and AbilityKey(planner.ability) == AbilityKey(ability) and planner.scope == scope
    if not keepRows or not same then
        planner.assignments = ability and ns:GetAbilityAssignments(GetPlanText(), ability, scope) or {}
        if not same then
            local first = planner.assignments[1]
            planner.testCount:SetValue(tostring(first and (first.casts and first.casts[1] or first.from) or 1))
            planner.testSeconds:SetValue(tostring(UI().testSeconds or 15))
            ResetCards(planner.cardList)
        end
    end
    planner.ability, planner.scope = ability, scope
    local specKey, diffSlug = Selected()
    local record = ns:GetRecording(boss, diffSlug)
    planner.cardTimeline = record and ns:BuildTimeline(specKey, GetPlanText(), record, boss) or nil
    planner.cardList.timeline = planner.cardTimeline
    planner.alsoAll:Hide()
    if not ability then
        FillCards(planner.cardList, {})
        planner.abilityName:SetText("No boss abilities")
        planner.abilityInfo:SetText("")
        planner.abilityIcon:SetTexture(QUESTION_MARK)
        planner.empty:SetText("This boss has no abilities listed yet. Pull it with BigWigs or DBM and the abilities they show bars for appear here.")
        planner.empty:Show()
        planner.addButton:Hide()
        return
    end
    planner.addButton:Show()
    local name, icon = SpellNameAndIcon(ability.spellId, ability.name)
    planner.abilityName:SetText(name)
    planner.abilityIcon:SetTexture(icon)
    local where = ScopeText(boss, scope)
    planner.abilityInfo:SetText((where and (scope == 'all' and "Triggers in every stage" or ("Only in " .. where)) or "") ..
        (where and "  ·  " or "") .. (ability.spellId and ("spell id " .. ability.spellId) or "matched by name"))
    if scope ~= 'all' then
        local forAll = ns:GetAbilityAssignments(GetPlanText(), ability, 'all')
        if #forAll > 0 then
            local names = {}
            for _, assignment in ipairs(forAll) do
                table.insert(names, assignment.entry)
            end
            planner.alsoAll.label:SetText("Also triggers here, set for every stage: " .. table.concat(names, ", "))
            planner.alsoAll:Show()
        end
    end

    local y = 0
    if #planner.assignments == 0 then
        planner.empty:SetText("Nothing assigned to " .. name .. (scope ~= 'all' and where and (" in " .. where) or "") .. " yet.\n" ..
            "Add an assignment below, choose what to cast, and how many seconds before " .. name .. " it should land.")
        planner.empty:Show()
        y = 68
    else
        planner.empty:Hide()
    end
    local items = {}
    for _, assignment in ipairs(planner.assignments) do
        table.insert(items, { group = planner, assignment = assignment, ability = ability, scope = scope })
    end
    y = FillCards(planner.cardList, items, y)
    planner.assignmentList:SetContentHeight(y + 8)
end

--Redraws the page from the saved settings. keepRows keeps the assignment cards of the ability as they are, so cards
--that have no ramp or spell yet stay
function Refresh(keepRows)
    if not planner then
        return
    end
    local specKey, _, boss = Selected()
    ns:RefreshBossBar()
    local planText = GetPlanText()
    RefreshTest()

    local top = RefreshStageTabs(boss) and -TABS_H or 0
    planner.listWell:ClearAllPoints()
    planner.listWell:SetPoint("TOPLEFT", 0, top)
    planner.listWell:SetPoint("BOTTOMLEFT", 0, 0)
    --The previews column only shows when the window is wide enough to keep room for the assignments
    local showPreviews = ns:WindowContentWidth() >= 1010
    planner.previews:SetShown(showPreviews)
    planner.right:ClearAllPoints()
    planner.right:SetPoint("TOPLEFT", RIGHT_X, top)
    planner.right:SetPoint("BOTTOMRIGHT", showPreviews and (-PREVIEW_W - 32) or 0, 0)
    planner.previews:ClearAllPoints()
    planner.previews:SetPoint("TOPRIGHT", 0, top)
    planner.previews:SetPoint("BOTTOMRIGHT", 0, 0)

    local lines = AbilityListLines(boss, ns:GetPlannerAbilities(boss, planText, UI().difficulty == 15), planText)
    local selected = SelectedLine(lines)
    RefreshAbilities(lines, selected, planText)

    local tab = UI().plannerTab
    if tab ~= 'plan' and tab ~= 'note' then
        tab = 'assignments'
    end
    for _, button in ipairs({ planner.planButton, planner.shareButton }) do
        button.underline:SetColorTexture(Accent(button.key == tab and 1 or 0))
    end
    planner.assignmentsTab:SetShown(tab == 'assignments')
    planner.planTextTab:SetShown(tab == 'plan')
    planner.noteTab:SetShown(tab == 'note')
    RefreshAssignments(selected, keepRows)
    if showPreviews then
        RefreshPreviews(planText)
    end
    if tab == 'plan' then
        planner.planUndo:SetShown(planner.copyUndo ~= nil)
        if not planner.planBox:HasFocus() then
            planner.planBox:SetText(planText)
            planner.planStatus:SetText(ns.specNames[specKey] .. ", " .. ns.difficulties[UI().difficulty].name .. " " .. ns.bosses[boss].name)
            planner.planStatus:SetTextColor(1, 1, 1, 0.53)
        end
    elseif tab == 'note' then
        RefreshShare()
    end
end

ns:RegisterPage('plans', "Plans", 1, function(page)
    planner = { page = page }
    BuildList(page)
    BuildRight(page)
    BuildPreviews(page)
    ns:SetPageTestHandler('plans', RefreshTest)
end, function()
    Refresh()
end, { icon = 'rail-plans', bossBar = true })

--The boss's ability that a cast of the recorded pull is of, the same one as in the ability list when it is listed
local function FindAbility(boss, name, spellId)
    for _, ability in ipairs(ns:GetPlannerAbilities(boss, GetPlanText(), UI().difficulty == 15)) do
        if (spellId and ability.spellId == spellId) or (ability.name and name and ability.name:lower() == name:lower()) then
            return ability
        end
    end
    return { spellId = spellId, name = name }
end

--Selects an ability in the ability list, for every stage or on its stage's tab
local function SelectAbility(ability, scope)
    local ui = UI()
    ui.ability, ui.abilityScope, ui.stageTab, ui.plannerTab = AbilityKey(ability), scope, scope, 'assignments'
end

--What the Timeline page shares with this page
ns.plannerKit = {
    Selected = Selected, GetPlanText = GetPlanText, SpellNameAndIcon = SpellNameAndIcon, AbilityKey = AbilityKey,
    StageName = StageName, ShortStageName = ShortStageName, HasStages = HasStages, IsIntermission = IsIntermission,
    NewCardList = NewCardList, FillCards = FillCards, ResetCards = ResetCards, OpenEntryMenu = OpenEntryMenu,
    ConflictTooltip = ConflictTooltip, CastsText = CastsText, EntryIcon = EntryIcon, TimingText = TimingText, FindAbility = FindAbility,
    SelectAbility = SelectAbility, CARD_H = CARD_H, QUESTION_MARK = QUESTION_MARK
}

--For tests
function ns:GetPlannerWidgets()
    return planner
end
