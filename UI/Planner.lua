local _, ns = ...

--The Plans page: pick a spec, difficulty and boss on the left, one of the boss's abilities in the middle, and assign
--ramps or spells to it on the right, for every cast or chosen casts, landing a number of seconds before the ability.
--Assignments are saved as ability lines in the boss's plan, which the Plan text tab shows in full

local theme = ns.theme
local LEFT_X, LEFT_W = 0, 196
local MID_X, MID_W = 210, 276
local RIGHT_X = 500
local RIGHT_W = 432
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
-- Left: spec, difficulty, boss and test
------------------------------------------------------------------------------------------------------------------------

local Refresh
local ConflictTooltip
local CopyMenuItems, CopyPlanTo, HistoryMenuItems
local NotReadyCasts

local function Column(page, x, width)
    local column = CreateFrame("Frame", nil, page)
    column:SetPoint("TOPLEFT", x, 0)
    column:SetPoint("BOTTOMLEFT", x, 0)
    column:SetWidth(width)
    return column
end

local function BuildLeft(page)
    local left = Column(page, LEFT_X, LEFT_W)
    ns:SectionLabel(left, "Spec"):SetPoint("TOPLEFT", 0, 0)
    planner.specButton = ns:Dropdown(left, LEFT_W, 26, function() return ns.specNames[ns:SelectedSpec()] end,
        function() return ns:SpecMenuItems() end, function(specKey)
            UI().spec = specKey
            UI().ability = nil
            Refresh()
        end)
    planner.specButton:SetPoint("TOPLEFT", 0, -16)

    ns:SectionLabel(left, "Difficulty"):SetPoint("TOPLEFT", 0, -56)
    planner.difficulty = ns:Segmented(left, {
        { text = ns.difficulties[15].name, value = 15 },
        { text = ns.difficulties[16].name, value = 16 }
    }, LEFT_W, 26, function() return UI().difficulty end, function(diffId)
        UI().difficulty = diffId
        Refresh()
    end)
    planner.difficulty:SetPoint("TOPLEFT", 0, -72)

    ns:SectionLabel(left, "Boss"):SetPoint("TOPLEFT", 0, -112)
    planner.bossList = ns:ScrollList(left)
    planner.bossList:SetPoint("TOPLEFT", 0, -128)
    planner.bossList:SetPoint("BOTTOMRIGHT", 0, 112)
    planner.bossRows = {}
    planner.raidHeaders = {}
    for index, raid in ipairs(ns.raids) do
        local header = ns:FoldHeader(planner.bossList.content, 24)
        header.label:SetText(raid.name:upper())
        header.raid = raid
        header:SetScript("OnClick", function()
            local folded = UI().foldedRaids
            folded[raid.name] = not header.folded
            Refresh()
        end)
        planner.raidHeaders[index] = header
        for _, boss in ipairs(raid.bosses) do
            local row = ns:ListRow(planner.bossList.content, ROW_H)
            row.label:SetPoint("LEFT", 20, 0)
            row.label:SetPoint("RIGHT", -8, 0)
            row.label:SetText(boss.name)
            row.encounterId = boss.encounterId
            row:SetScript("OnClick", function()
                UI().boss = boss.encounterId
                UI().ability = nil
                Refresh()
            end)
            planner.bossRows[boss.encounterId] = row
        end
    end

    planner.replay = ns:Button(left, "Replay pull", LEFT_W, 26, function()
        if ns:IsTesting() then
            ns:StopTest()
            return
        end
        local specKey, diffSlug, boss = Selected()
        ns:StartTest(specKey, diffSlug, boss)
    end, true)
    planner.replay:SetPoint("BOTTOMLEFT", 0, 0)
    planner.recordingInfo = ns:Text(left, 10, theme.dim)
    planner.recordingInfo:SetPoint("BOTTOMLEFT", planner.replay, "TOPLEFT", 0, 6)
    planner.recordingInfo:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    planner.recordingInfo:SetWordWrap(true)
    planner.recordingInfo:SetJustifyV("BOTTOM")
    local testLabel = ns:SectionLabel(left, "Test")
    testLabel:SetPoint("BOTTOMLEFT", planner.recordingInfo, "TOPLEFT", 0, 6)
    local testHelp = ns:HelpIcon(left, "Testing a plan",
        "Every pull of a boss with BigWigs or DBM is recorded: the stages and ability bars they showed. Replay pull runs the " ..
        "longest recorded pull of the selected boss and difficulty again with your current plan, so its reminders show and " ..
        "speak as they would in the raid. Nothing has to be pulled, it works anywhere, also while hitting a target dummy.\n\n" ..
        "Without a recorded pull, test one ability with Test cast on the right.")
    testHelp:SetPoint("LEFT", testLabel, "RIGHT", 6, 0)
end

--Raids are folded and unfolded by clicking their name. A raid starts folded when Config/Bosses.lua says so
local function RaidFolded(raid)
    local folded = UI().foldedRaids
    if folded[raid.name] == nil then
        folded[raid.name] = raid.collapsed == true
    end
    return folded[raid.name]
end

local function RefreshBosses(selectedBoss)
    UI().foldedRaids = UI().foldedRaids or {}
    local list = planner.bossList
    local y = 0
    for index, raid in ipairs(ns.raids) do
        local header = planner.raidHeaders[index]
        local folded = RaidFolded(raid)
        local hasSelected = ns.bosses[selectedBoss] and ns.bosses[selectedBoss].raid == raid.name
        header:SetFolded(folded)
        header:SetHighlighted(folded and hasSelected)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, y)
        header:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
        y = y - 24
        for _, boss in ipairs(raid.bosses) do
            local row = planner.bossRows[boss.encounterId]
            row:SetSelected(boss.encounterId == selectedBoss)
            row:SetShown(not folded)
            if not folded then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, y)
                row:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
                y = y - ROW_H
            end
        end
    end
    list:SetContentHeight(-y)
end

local function RefreshTest()
    local _, diffSlug, boss = Selected()
    local recording = ns:GetRecording(boss, diffSlug)
    local testing = ns:IsTesting()
    if recording then
        planner.recordingInfo:SetText("Recorded pull of " .. ns:FormatTime(recording.duration) .. " on " .. recording.date ..
            ", replayed with this plan.")
    else
        planner.recordingInfo:SetText("No pull of this boss recorded yet. Pull it once with BigWigs or DBM to replay it here.")
    end
    planner.replay.label:SetText(testing and "Stop test" or "Replay pull")
    planner.replay:SetAlpha((recording or testing) and 1 or 0.4)
    planner.replay:SetEnabled(recording ~= nil or testing)
    if planner.testCast then
        planner.testCast.label:SetText(testing and "Stop test" or "Test cast")
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Middle: the boss's abilities, by stage or once for all stages
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

--Which view the ability list shows: 'stage' lists abilities under each stage they happen in, 'all' lists them once
local function AbilityView(boss)
    if not HasStages(boss) then
        return 'all'
    end
    return UI().abilityView == 'all' and 'all' or 'stage'
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
    for _, info in ipairs(ns.bossStages[boss]) do
        local stage = ns:PhaseKey(info.stage)
        local labelled = false
        for _, ability in ipairs(abilities) do
            if InStage(ability, stage) then
                if not labelled then
                    table.insert(lines, { label = info.name })
                    labelled = true
                end
                table.insert(lines, { ability = ability, scope = stage })
            end
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

local function BuildMiddle(page)
    local middle = Column(page, MID_X, MID_W)
    ns:Fill(middle, theme.well)
    ns:Border(middle, theme.border)
    ns:SectionLabel(middle, "Boss abilities"):SetPoint("TOPLEFT", 10, -10)
    local hint = ns:Text(middle, 10, theme.section, "RIGHT")
    hint:SetPoint("TOPRIGHT", -10, -10)
    hint:SetText("ASSIGNED")
    planner.view = ns:Segmented(middle, {
        { text = "By stage", value = 'stage', tooltip = "Abilities under each stage they happen in. Assignments made here only trigger in that stage." },
        { text = "All stages", value = 'all', tooltip = "Every ability once. Assignments made here trigger in every stage." }
    }, MID_W - 20, 22, function() return UI().abilityView == 'all' and 'all' or 'stage' end, function(view)
        UI().abilityView = view
        UI().abilityScope = view == 'all' and 'all' or nil
        Refresh()
    end)
    planner.view:SetPoint("TOPLEFT", 10, -28)
    local list = ns:ScrollList(middle)
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
    row.label:SetPoint("RIGHT", -34, 0)
    row.badge = ns:Text(row, 11, theme.text, "RIGHT")
    row.badge:SetPoint("RIGHT", -12, 0)
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
    planner.view:SetShown(HasStages(boss))
    planner.view:Refresh()
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", 1, HasStages(boss) and -56 or -28)
    list:SetPoint("BOTTOMRIGHT", -1, 1)
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
            --What triggers on this line: its own assignments, and on a stage line those for every stage too
            local count = #ns:GetAbilityAssignments(planText, line.ability, line.scope)
            if line.scope ~= 'all' then
                count = count + #ns:GetAbilityAssignments(planText, line.ability, 'all')
            end
            row.badge:SetText(count > 0 and tostring(count) or '')
            row.badge:SetTextColor(Accent())
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

local function SaveAssignments()
    local _, _, boss = Selected()
    if planner.ability then
        local specKey, diffSlug = Selected()
        ns:BackupPlan(specKey, diffSlug, boss, "Before editing assignments", 600)
        SetPlanText(ns:SetAbilityAssignments(GetPlanText(), boss, planner.ability, planner.assignments, planner.scope))
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
            Refresh(true)
            card.entryBox:SetFocus()
            return
        end
        card.assignment.entry = value
        SaveAssignments()
        Refresh(true)
    end)
end

local function Capitalized(text)
    return (text:gsub('^%l', string.upper))
end

local function AssignmentCard(index)
    local card = planner.cards[index]
    if card then
        return card
    end
    card = CreateFrame("Frame", nil, planner.assignmentList.content)
    card:SetHeight(CARD_H - 8)
    ns:Fill(card, { 1, 1, 1, 0.03 })
    ns:Border(card, theme.border)

    --What: the ramp, spell or trinket
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(28, 28)
    card.icon:SetPoint("TOPLEFT", 8, -8)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.pick = ns:Dropdown(card, 300, 28, function() return card.assignment and card.assignment.entry or '' end,
        function() return {} end, function() end)
    card.pick:SetScript("OnClick", function() OpenEntryMenu(card) end)
    card.pick:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
    card.pick.placeholder = ns:Text(card.pick, 12, theme.section)
    card.pick.placeholder:SetPoint("LEFT", 10, 0)
    card.pick.placeholder:SetText("Choose what to cast...")
    ns:Tooltip(card.pick, "What to cast", "A ramp from the Ramps page, one of your cooldowns, a trinket, or any spell or item you type.")
    card.entryBox = ns:EditBox(card, 300, 28, function(text)
        card.assignment.entry = text:match('^%s*(.-)%s*$')
        card.typing = false
        SaveAssignments()
        Refresh(true)
    end)
    card.entryBox:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
    card.entryBox:SetPlaceholder("spell name, item name or item:id")
    card.entryBox:HookScript("OnEditFocusLost", function()
        if card.typing then
            card.typing = false
            Refresh(true)
        end
    end)
    card.delete = ns:Button(card, "x", 24, 24, function()
        table.remove(planner.assignments, card.index)
        SaveAssignments()
        Refresh(true)
    end)
    card.delete:SetPoint("TOPRIGHT", -8, -10)
    ns:Tooltip(card.delete, "Remove this assignment")

    --When: seconds before the ability, and which casts
    local lands = ns:Text(card, 11, theme.dim)
    lands:SetPoint("TOPLEFT", 8, -50)
    lands:SetText("Lands")
    local function Adjust(delta)
        return function()
            card.assignment.before = (card.assignment.before or 0) + delta
            SaveAssignments()
            Refresh(true)
        end
    end
    card.minus = ns:Button(card, "-", 22, 24, Adjust(-1))
    card.minus:SetPoint("LEFT", lands, "RIGHT", 8, 0)
    card.before = ns:EditBox(card, 40, 24, function(text)
        card.assignment.before = tonumber(text) or 0
        SaveAssignments()
        Refresh(true)
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
                Refresh(true)
                card.castsBox:SetFocus()
                return
            end
            card.customCasts = false
            card.assignment.casts, card.assignment.every, card.assignment.from = choice.casts, choice.every, choice.every and choice.from or nil
            SaveAssignments()
            Refresh(true)
        end)
    card.casts:SetPoint("LEFT", card.beforeText, "RIGHT", 8, 0)
    ns:Tooltip(card.casts, "Which casts", CASTS_HELP)
    card.castsBox = ns:EditBox(card, 54, 24, function(text)
        if SetCasts(card.assignment, text) then
            SaveAssignments()
        end
        Refresh(true)
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
        local timeline, append = planner.cardTimeline, false
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
    planner.cards[index] = card
    return card
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
    planner.abilityIcon:SetSize(30, 30)
    planner.abilityIcon:SetPoint("TOPLEFT", 0, -2)
    planner.abilityIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    planner.abilityName = ns:Text(tab, 15)
    planner.abilityName:SetPoint("TOPLEFT", planner.abilityIcon, "TOPRIGHT", 10, -1)
    planner.abilityName:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.abilityInfo = ns:Text(tab, 10, theme.dim)
    planner.abilityInfo:SetPoint("BOTTOMLEFT", planner.abilityIcon, "BOTTOMRIGHT", 10, 1)
    planner.abilityInfo:SetPoint("RIGHT", tab, "RIGHT", 0, 0)

    --On a stage, what is assigned for every stage triggers too
    planner.alsoAll = CreateFrame("Button", nil, tab)
    planner.alsoAll:SetPoint("TOPLEFT", 0, -40)
    planner.alsoAll:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    planner.alsoAll:SetHeight(16)
    planner.alsoAll.label = ns:Text(planner.alsoAll, 10, theme.dim)
    planner.alsoAll.label:SetPoint("LEFT")
    planner.alsoAll.label:SetPoint("RIGHT")
    planner.alsoAll:SetScript("OnClick", function()
        UI().abilityView = 'all'
        UI().abilityScope = 'all'
        Refresh()
    end)
    ns:Tooltip(planner.alsoAll, "Assigned for every stage", "These trigger in every stage this ability happens in. Click to edit them in the All stages list.")

    local list = ns:ScrollList(tab)
    list:SetPoint("TOPLEFT", 0, -60)
    list:SetPoint("BOTTOMRIGHT", 0, 74)
    planner.assignmentList = list
    planner.cards = {}

    planner.empty = ns:Text(list.content, 12, theme.dim)
    planner.empty:SetPoint("TOPLEFT", 0, -4)
    planner.empty:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
    planner.empty:SetWordWrap(true)
    planner.empty:SetJustifyV("TOP")
    planner.empty:SetHeight(64)
    planner.addButton = ns:Button(list.content, "+ Add assignment", 160, 28, AddAssignment, true)

    --Testing one cast of the ability
    local rule = tab:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 66)
    rule:SetPoint("BOTTOMRIGHT", 0, 66)
    rule:SetColorTexture(1, 1, 1, 0.06)
    local testLabel = ns:SectionLabel(tab, "Test cast")
    testLabel:SetPoint("BOTTOMLEFT", 0, 46)
    local castText = ns:Text(tab, 11, theme.dim)
    castText:SetPoint("BOTTOMLEFT", 0, 13)
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
    planner.testCast:SetPoint("BOTTOMRIGHT", 0, 12)
    ns:Tooltip(planner.testCast, "Test cast",
        "Pretends your boss mod shows a bar for this cast of the ability, and shows the reminders of its assignments as they " ..
        "would come. Other lines of the plan are left out.")
end

------------------------------------------------------------------------------------------------------------------------
-- Right: the timeline of the recorded pull, with the plan's reminders
------------------------------------------------------------------------------------------------------------------------

local TIMELINE_ROW = { stage = 24, cast = 20, reminder = 18 }

--Opens the ability of a cast on the timeline in the Assignments tab, on its stage when the list is by stage
local function OpenCast(cast)
    local _, _, boss = Selected()
    for _, ability in ipairs(ns:GetPlannerAbilities(boss, GetPlanText(), UI().difficulty == 15)) do
        if (cast.spellId and ability.spellId == cast.spellId) or (ability.name and ability.name:lower() == cast.name:lower()) then
            UI().ability = AbilityKey(ability)
            UI().abilityScope = AbilityView(boss) == 'stage' and cast.stage or 'all'
            UI().plannerTab = 'assignments'
            Refresh()
            return
        end
    end
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

local function TimelineRow(index)
    local row = planner.timelineRows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, planner.timelineList.content)
    row.background = ns:Fill(row, { 1, 1, 1, 0 })
    row.time = ns:Text(row, 10, theme.dim)
    row.time:SetPoint("LEFT", 4, 0)
    row.time:SetWidth(34)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label = ns:Text(row, 11)
    row.label:SetPoint("RIGHT", -46, 0)
    row.play = ns:Button(row, "Play", 38, 16, function()
        local specKey, diffSlug, boss = Selected()
        ns:StartTest(specKey, diffSlug, boss, nil, math.max(0, row.at - 5))
    end)
    row.play:SetPoint("RIGHT", -2, 0)
    row.play.label:SetFont(ns:GetFont(), 9, "")
    ns:Tooltip(row.play, "Replay from here", "Replays the recorded pull from 5 seconds before this, with your plan.")
    row:SetScript("OnClick", function(self)
        if self.cast then
            OpenCast(self.cast)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if self.cast then
            self.background:SetColorTexture(1, 1, 1, 0.06)
        end
    end)
    row:SetScript("OnLeave", function(self) self:Paint() end)
    ns:Tooltip(row, function(tooltip, self)
        if self.conflict then
            return ConflictTooltip(tooltip, self.reminder)
        end
        if not self.cast then
            return false
        end
        tooltip:SetText(self.cast.name .. (self.cast.count and (" (" .. self.cast.count .. ")") or ""), 1, 1, 1)
        tooltip:AddLine("Goes off at " .. ns:FormatTime(self.cast.at), 0.7, 0.7, 0.7)
        tooltip:AddLine(self.cast.assigned and "Click to see its assignments" or "Click to assign something to it", Accent())
    end)
    function row:Paint()
        local r, g, b = ns:GetAccent()
        if self.current then
            self.background:SetColorTexture(r, g, b, 0.22)
        elseif self.kind == 'stage' then
            self.background:SetColorTexture(r, g, b, 0.1)
        else
            self.background:SetColorTexture(1, 1, 1, 0)
        end
    end
    planner.timelineRows[index] = row
    return row
end

local function BuildTimelineTab(panel)
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetAllPoints()
    planner.timelineTab = tab
    planner.timelineInfo = ns:Text(tab, 11, theme.dim)
    planner.timelineInfo:SetPoint("TOPLEFT", 0, -4)
    planner.timelineInfo:SetPoint("RIGHT", tab, "RIGHT", -180, 0)
    planner.timelineAssigned = ns:Checkbox(tab, "Only assigned abilities", function() return UI().timelineAssigned end, function(value)
        UI().timelineAssigned = value or nil
        Refresh()
    end)
    planner.timelineAssigned:SetWidth(170)
    planner.timelineAssigned:SetPoint("TOPRIGHT", 0, 0)
    local legend = ns:Text(tab, 10, theme.dim)
    legend:SetPoint("TOPLEFT", 0, -24)
    legend:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    legend:SetText("Boss abilities in white, your reminders in green. Click an ability to assign to it, Play replays from there.")
    local well = CreateFrame("Frame", nil, tab)
    well:SetPoint("TOPLEFT", 0, -44)
    well:SetPoint("BOTTOMRIGHT", 0, 0)
    ns:Fill(well, theme.well)
    ns:Border(well, theme.border)
    planner.timelineList = ns:ScrollList(well)
    planner.timelineList:SetPoint("TOPLEFT", 1, -1)
    planner.timelineList:SetPoint("BOTTOMRIGHT", -1, 1)
    planner.timelineRows = {}
    planner.timelineEmpty = ns:Text(well, 12, theme.dim)
    planner.timelineEmpty:SetPoint("TOPLEFT", 12, -12)
    planner.timelineEmpty:SetPoint("RIGHT", well, "RIGHT", -12, 0)
    planner.timelineEmpty:SetWordWrap(true)
end

--The lines of the timeline in order: stage changes, boss casts and reminders. At the same time a stage comes first, then
--reminders, then the cast they lead up to
local function TimelineLines(timeline, boss)
    local lines = {}
    for _, stage in ipairs(timeline.stages) do
        if stage.at > 0 or stage.stage ~= '1' then
            table.insert(lines, { kind = 'stage', at = stage.at, order = 0, text = ScopeText(boss, stage.stage) or ("Stage " .. stage.stage) })
        end
    end
    for _, cast in ipairs(timeline.casts) do
        if cast.assigned or not UI().timelineAssigned then
            table.insert(lines, { kind = 'cast', at = cast.at, order = 2, cast = cast })
        end
    end
    for _, reminder in ipairs(timeline.reminders) do
        table.insert(lines, { kind = 'reminder', at = reminder.at, order = 1, reminder = reminder })
    end
    table.sort(lines, function(a, b)
        if math.abs(a.at - b.at) > 0.05 then
            return a.at < b.at
        end
        return a.order < b.order
    end)
    return lines
end

local function RefreshTimeline()
    local specKey, diffSlug, boss = Selected()
    local record = ns:GetRecording(boss, diffSlug)
    for _, row in ipairs(planner.timelineRows) do
        row:Hide()
    end
    planner.timelineLines = nil
    if not record then
        planner.timelineInfo:SetText("No recorded pull")
        planner.timelineEmpty:SetText("No pull of " .. ns.bosses[boss].name .. " on " .. ns.difficulties[UI().difficulty].name ..
            " recorded yet. Pull it once with BigWigs or DBM, and the timeline shows when each ability went off and when your reminders show.")
        planner.timelineEmpty:Show()
        planner.timelineList:SetContentHeight(1)
        return
    end
    planner.timelineEmpty:Hide()
    local timeline = ns:BuildTimeline(specKey, GetPlanText(), record, boss)
    planner.timelineInfo:SetText("Recorded pull of " .. ns:FormatTime(record.duration) .. " on " .. record.date ..
        (timeline.conflicts > 0 and ("  |cffff5a4d" .. timeline.conflicts .. " not ready in time|r") or ""))
    local lines = TimelineLines(timeline, boss)
    local r, g, b = ns:GetAccent()
    local y = 0
    for index, line in ipairs(lines) do
        local row = TimelineRow(index)
        row.kind, row.at, row.cast, row.current = line.kind, line.at, line.cast, false
        row.reminder = line.reminder
        row.conflict = line.reminder and line.reminder.use and line.reminder.use.conflict
        local height = TIMELINE_ROW[line.kind]
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", planner.timelineList.content, "RIGHT", 0, 0)
        line.y = y
        row.time:SetText(ns:FormatTime(line.at))
        row.icon:ClearAllPoints()
        row.label:ClearAllPoints()
        row.label:SetPoint("RIGHT", -46, 0)
        row.play:SetShown(line.kind ~= 'reminder')
        if line.kind == 'stage' then
            row.icon:Hide()
            row.label:SetPoint("LEFT", row.time, "RIGHT", 6, 0)
            row.label:SetText(line.text:upper())
            row.label:SetTextColor(r, g, b, 1)
            row.time:SetTextColor(r, g, b, 1)
        elseif line.kind == 'cast' then
            local cast = line.cast
            local _, icon = SpellNameAndIcon(cast.spellId, cast.name)
            row.icon:SetSize(16, 16)
            row.icon:SetPoint("LEFT", row.time, "RIGHT", 6, 0)
            row.icon:SetTexture(icon)
            row.icon:Show()
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.label:SetText(cast.name .. (cast.count and (" (" .. cast.count .. ")") or ""))
            row.label:SetTextColor(1, 1, 1, cast.assigned and 1 or 0.6)
            row.time:SetTextColor(1, 1, 1, 0.53)
        else
            local reminder = line.reminder
            row.icon:SetSize(14, 14)
            row.icon:SetPoint("LEFT", row.time, "RIGHT", 18, 0)
            row.icon:SetTexture(reminder.icon or QUESTION_MARK)
            row.icon:Show()
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.label:SetText((row.conflict and "! " or "") .. (reminder.approximate and "~ " or "") .. reminder.text)
            if row.conflict then
                row.label:SetTextColor(ErrorColor())
                row.time:SetTextColor(ErrorColor(0.8))
            else
                row.label:SetTextColor(r, g, b, 0.9)
                row.time:SetTextColor(r, g, b, 0.7)
            end
        end
        row:Paint()
        row:Show()
        y = y - height
    end
    planner.timelineLines = lines
    planner.timelineList:SetContentHeight(-y + 4)
end

--While a replay runs, the line it has reached is lit and kept in view
local function UpdatePlayhead()
    local lines = planner.timelineLines
    if not lines or not planner.timelineTab:IsShown() then
        return
    end
    local now = ns:IsTesting() and not ns.fight.test.ability and (GetTime() - ns.fight.start) or nil
    local current
    for index, line in ipairs(lines) do
        if now and line.at <= now then
            current = index
        end
    end
    for index, row in ipairs(planner.timelineRows) do
        if row:IsShown() then
            row.current = index == current
            row:Paint()
        end
    end
    if current then
        local list = planner.timelineList
        local top = -lines[current].y
        local visible = list:GetHeight() or 0
        local scroll = list:GetVerticalScroll() or 0
        if top < scroll or top > scroll + visible - 40 then
            list:SetVerticalScroll(math.max(0, math.min(top - visible / 3, list:GetVerticalScrollRange() or 0)))
        end
    end
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

local TABS = { { key = 'assignments', text = "Assignments" }, { key = 'plan', text = "Plan text" }, { key = 'note', text = "Share" },
    { key = 'timeline', text = "Timeline" } }

local function BuildRight(page)
    local right = Column(page, RIGHT_X, RIGHT_W)
    planner.tabButtons = {}
    local x = 0
    for _, info in ipairs(TABS) do
        local button = CreateFrame("Button", nil, right)
        button:SetSize(96, 24)
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
        x = x + 106
    end
    local panel = CreateFrame("Frame", nil, right)
    panel:SetPoint("TOPLEFT", 0, -36)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    BuildAssignmentsTab(panel)
    BuildPlanTextTab(panel)
    BuildNoteTab(panel)
    BuildTimelineTab(panel)
end

--The casts of an ability in the recorded pull on which an assignment's spell won't be ready, like 'cast 3 (02:10)'
function NotReadyCasts(assignment, ability, scope)
    local timeline = planner.cardTimeline
    if not timeline then
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
            for _, card in ipairs(planner.cards) do
                card.typing, card.customCasts = false, false
            end
        end
    end
    planner.ability, planner.scope = ability, scope
    local specKey, diffSlug = Selected()
    local record = ns:GetRecording(boss, diffSlug)
    planner.cardTimeline = record and ns:BuildTimeline(specKey, GetPlanText(), record, boss) or nil
    for _, card in ipairs(planner.cards) do
        card:Hide()
    end
    planner.alsoAll:Hide()
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
            "Add an assignment, choose what to cast, and how many seconds before " .. name .. " it should land.")
        planner.empty:Show()
        y = -68
    else
        planner.empty:Hide()
    end
    for index, assignment in ipairs(planner.assignments) do
        local card = AssignmentCard(index)
        card.index = index
        card.assignment = assignment
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
        local notReady = not isError and NotReadyCasts(assignment, ability, scope)
        if notReady then
            text, isError = "Not ready in time on " .. notReady .. "  ·  see the Timeline", true
        end
        card.note:SetText(text)
        if isError then
            card.note:SetTextColor(ErrorColor())
        else
            card.note:SetTextColor(1, 1, 1, 0.53)
        end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 0, y)
        card:SetPoint("RIGHT", planner.assignmentList.content, "RIGHT", 0, 0)
        card:Show()
        y = y - CARD_H
    end
    planner.addButton:ClearAllPoints()
    planner.addButton:SetPoint("TOPLEFT", 0, y - 4)
    planner.addButton:Show()
    planner.assignmentList:SetContentHeight(-y + 40)
end

--Redraws the page from the saved settings. keepRows keeps the assignment cards of the ability as they are, so cards
--that have no ramp or spell yet stay
function Refresh(keepRows)
    if not planner then
        return
    end
    local specKey, _, boss = Selected()
    local planText = GetPlanText()
    planner.specButton:Refresh()
    planner.difficulty:Refresh()
    RefreshBosses(boss)
    RefreshTest()

    local lines = AbilityListLines(boss, ns:GetPlannerAbilities(boss, planText, UI().difficulty == 15), planText)
    local selected = SelectedLine(lines)
    RefreshAbilities(lines, selected, planText)

    local tab = UI().plannerTab
    if tab ~= 'plan' and tab ~= 'note' and tab ~= 'timeline' then
        tab = 'assignments'
    end
    for key, button in pairs(planner.tabButtons) do
        local active = key == tab
        button.label:SetTextColor(1, 1, 1, active and 1 or 0.5)
        button.underline:SetColorTexture(Accent(active and 1 or 0))
    end
    planner.assignmentsTab:SetShown(tab == 'assignments')
    planner.planTextTab:SetShown(tab == 'plan')
    planner.noteTab:SetShown(tab == 'note')
    planner.timelineTab:SetShown(tab == 'timeline')
    if tab == 'timeline' then
        RefreshTimeline()
        UpdatePlayhead()
    elseif tab == 'plan' then
        planner.planUndo:SetShown(planner.copyUndo ~= nil)
        if not planner.planBox:HasFocus() then
            planner.planBox:SetText(planText)
            planner.planStatus:SetText(ns.specNames[specKey] .. ", " .. ns.difficulties[UI().difficulty].name .. " " .. ns.bosses[boss].name)
            planner.planStatus:SetTextColor(1, 1, 1, 0.53)
        end
    elseif tab == 'note' then
        RefreshShare()
    else
        RefreshAssignments(selected, keepRows)
    end
end

ns:RegisterPage('plans', "Plans", 1, function(page)
    planner = { page = page }
    BuildLeft(page)
    BuildMiddle(page)
    BuildRight(page)
    ns:SetPageTestHandler('plans', function()
        RefreshTest()
        UpdatePlayhead()
    end)
end, function()
    Refresh()
end)

--For tests
function ns:GetPlannerWidgets()
    return planner
end
