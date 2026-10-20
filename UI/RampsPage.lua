local _, ns = ...

--The Ramps page: the ramps of a spec on the left, the steps of the selected ramp on the right

local theme = ns.theme
local LEFT_W = 220
local RIGHT_X = 240
local ROW_H = 26

local STEPS_HELP = "One step per line: |cffffd100when | text | options|r\n" ..
    "|cffffd100when|r  seconds before the ramp lands (20), global cooldowns before it (12gcd, shortened by your haste), or " ..
    "'charges <spell>' to show the step once that spell's charges need all the time left to come back.\n" ..
    "|cffffd100options|r  setup (a setup step), countdown (counts down on the icon), icon <spell>, say <text to speak>.\n" ..
    "The last step, at 0, is when the ramp lands: that is the time a plan line or an assignment gives."

local page

local function UI()
    return ns.db.ui
end

local function Accent(alpha)
    local r, g, b = ns:GetAccent()
    return r, g, b, alpha or 1
end

local function SelectedRamp()
    local ramps = ns:GetRamps(ns:SelectedSpec())
    if not ramps[UI().ramp or ''] then
        UI().ramp = ns:GetRampNames(ns:SelectedSpec())[1]
    end
    return UI().ramp, UI().ramp and ramps[UI().ramp]
end

local function SetStatus(text, color)
    page.status:SetText(text)
    if color == 'error' then
        page.status:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
    elseif color == 'accent' then
        page.status:SetTextColor(Accent())
    else
        page.status:SetTextColor(1, 1, 1, 0.53)
    end
end

--A ramp's steps in a line, like '4 steps, the first 20s before it lands'
local function Summary(ramp)
    local steps = ns:ParseRampSteps(ramp.steps)
    if not steps then
        return "These steps can't be read"
    end
    local first = 0
    local gcd = ns:GetGcd()
    for _, step in ipairs(steps) do
        first = math.max(first, step.seconds or (step.gcds and step.gcds * gcd) or 0)
    end
    return string.format("%d steps, the first %gs before it lands", #steps, math.floor(first * 10 + 0.5) / 10)
end

local Refresh

------------------------------------------------------------------------------------------------------------------------
-- The steps as a form: a row per step, written back as steps text when saved
------------------------------------------------------------------------------------------------------------------------

local UNITS = { { text = "seconds", value = 's' }, { text = "GCDs", value = 'gcd' }, { text = "charges of", value = 'charges' } }

local function Number(value)
    return string.format("%g", value)
end

--The rows of a ramp's steps text, nil when it can't be read
local function FormSteps(text)
    local steps = ns:ParseRampSteps(text or '')
    if not steps then
        return nil
    end
    local rows = {}
    for _, step in ipairs(steps) do
        local row = { text = step.text, say = step.tts or '', setup = step.prerequisite == true, countdown = step.countdown == true,
            icon = step.iconSpell }
        if step.chargesOf then
            row.unit, row.when = 'charges', tostring(step.chargesOf)
        elseif step.gcds then
            row.unit, row.when = 'gcd', Number(step.gcds)
        else
            row.unit, row.when = 's', Number(step.seconds or 0)
        end
        table.insert(rows, row)
    end
    return rows
end

--Steps text from the form's rows
local function StepsText(rows)
    local lines = {}
    for _, row in ipairs(rows) do
        local when = row.when ~= '' and row.when or '0'
        if row.unit == 'gcd' then
            when = when .. 'gcd'
        elseif row.unit == 'charges' then
            when = 'charges ' .. when
        end
        local parts = { when, row.text }
        if row.setup then
            table.insert(parts, 'setup')
        end
        if row.countdown then
            table.insert(parts, 'countdown')
        end
        if row.icon then
            table.insert(parts, 'icon ' .. tostring(row.icon))
        end
        if row.say and row.say ~= '' then
            table.insert(parts, 'say ' .. row.say)
        end
        table.insert(lines, table.concat(parts, ' | '))
    end
    return table.concat(lines, '\n')
end

local function Edited()
    page.formDirty = true
    SetStatus("Not saved yet")
end

--Takes what is typed in the form's boxes, also when Enter wasn't pressed
local function CollectForm()
    for _, row in ipairs(page.formRows) do
        if row:IsShown() and row.step then
            for _, field in ipairs({ 'when', 'text', 'say' }) do
                local value = (row[field]:GetText() or ''):match('^%s*(.-)%s*$')
                if value ~= (row.step[field] or '') then
                    row.step[field] = value
                    page.formDirty = true
                end
            end
        end
    end
end

local function FormRow(index)
    local row = page.formRows[index]
    if row then
        return row
    end
    row = CreateFrame("Frame", nil, page.formList.content)
    row:SetHeight(30)
    row.when = ns:EditBox(row, 70, 26, function(text)
        row.step.when = text:match('^%s*(.-)%s*$')
        Edited()
    end)
    row.when:SetJustifyH("CENTER")
    row.unit = ns:Dropdown(row, 96, 26, function()
        for _, unit in ipairs(UNITS) do
            if row.step and unit.value == row.step.unit then
                return unit.text
            end
        end
        return ''
    end, function() return UNITS end, function(value)
        row.step.unit = value
        Edited()
    end)
    ns:Tooltip(row.unit, "Before it lands", "How long before the ramp lands this step shows: seconds, global cooldowns (shortened " ..
        "by your haste), or once a spell's charges need all the time left to come back (type the spell in the box).")
    row.text = ns:EditBox(row, 250, 26, function(text)
        row.step.text = text:match('^%s*(.-)%s*$')
        Edited()
    end)
    row.text:SetPlaceholder("What to do")
    row.say = ns:EditBox(row, 140, 26, function(text)
        row.step.say = text:match('^%s*(.-)%s*$')
        Edited()
    end)
    row.say:SetPlaceholder("Say instead")
    ns:Tooltip(row.say, "Say instead", "What is said out loud for this step, when it should be shorter than the text. Empty says the text.")
    row.setup = ns:Checkbox(row, "setup", function() return row.step and row.step.setup end, function(value)
        row.step.setup = value
        Edited()
    end, "A setup step, like applying atonements before the ramp. Can be left out with the setup option on the Display page.")
    row.setup:SetWidth(70)
    row.countdown = ns:Checkbox(row, "countdown", function() return row.step and row.step.countdown end, function(value)
        row.step.countdown = value
        Edited()
    end, "Shows a countdown on the icon until the ramp lands.")
    row.countdown:SetWidth(96)
    row.delete = ns:Button(row, "x", 24, 24, function()
        CollectForm()
        table.remove(page.formSteps, row.index)
        Edited()
        Refresh()
    end)
    ns:Tooltip(row.delete, "Remove this step")
    page.formRows[index] = row
    return row
end

--The form needs this much room to show a step on one line, narrower it takes two
local FORM_WIDE = 790
local LINE_H = 30

--Puts a row's boxes on one line, or on two when the window is narrow: the message box takes the room there is
local function LayOutRow(row, wide)
    if row.wide == wide then
        return
    end
    row.wide = wide
    for _, widget in ipairs({ row.when, row.unit, row.text, row.say, row.setup, row.countdown, row.delete }) do
        widget:ClearAllPoints()
    end
    row:SetHeight(wide and LINE_H or 2 * LINE_H)
    row.when:SetPoint("TOPLEFT", 0, -2)
    row.unit:SetPoint("LEFT", row.when, "RIGHT", 6, 0)
    row.delete:SetPoint("TOPRIGHT", -2, -3)
    row.text:SetPoint("LEFT", row.unit, "RIGHT", 6, 0)
    if wide then
        row.countdown:SetPoint("RIGHT", row.delete, "LEFT", -4, 0)
        row.setup:SetPoint("RIGHT", row.countdown, "LEFT", -4, 0)
        row.say:SetPoint("RIGHT", row.setup, "LEFT", -10, 0)
        row.text:SetPoint("RIGHT", row.say, "LEFT", -6, 0)
    else
        row.text:SetPoint("RIGHT", row.delete, "LEFT", -6, 0)
        row.say:SetPoint("TOPLEFT", row.unit, "BOTTOMLEFT", 0, -4)
        row.countdown:SetPoint("TOPRIGHT", row.delete, "BOTTOMLEFT", -2, -5)
        row.setup:SetPoint("RIGHT", row.countdown, "LEFT", -4, 0)
    end
end

local function RefreshForm()
    for _, row in ipairs(page.formRows) do
        row:Hide()
    end
    local y = -2
    local wide = ns:WindowContentWidth() - RIGHT_X >= FORM_WIDE
    page.sayHeader:SetShown(wide)
    for index, step in ipairs(page.formSteps or {}) do
        local row = FormRow(index)
        LayOutRow(row, wide)
        row.index, row.step = index, step
        row.when:SetValue(step.when)
        row.unit:Refresh()
        row.text:SetValue(step.text or '')
        row.say:SetValue(step.say or '')
        row.setup:Refresh()
        row.countdown:Refresh()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", page.formList.content, "RIGHT", 0, 0)
        row:Show()
        y = y - (wide and LINE_H or 2 * LINE_H) - 2
    end
    page.addStep:ClearAllPoints()
    page.addStep:SetPoint("TOPLEFT", 0, y - 4)
    page.formList:SetContentHeight(-y + 40)
end

--Switches between the form and the text of the steps, taking what was edited along
local function SetEditor(mode)
    if mode == 'text' and page.formSteps then
        CollectForm()
        page.steps:SetText(StepsText(page.formSteps))
    elseif mode == 'form' then
        local rows = FormSteps(page.steps:GetText())
        if not rows then
            local _, problem = ns:ParseRampSteps(page.steps:GetText())
            SetStatus(problem, 'error')
            return
        end
        page.formSteps = rows
    end
    UI().rampEditor = mode
    Refresh()
end

local function Build(frame)
    page = { frame = frame, rows = {} }
    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(LEFT_W)
    ns:SectionLabel(left, "Spec"):SetPoint("TOPLEFT", 0, 0)
    page.spec = ns:Dropdown(left, LEFT_W, 26, function() return ns.specNames[ns:SelectedSpec()] end,
        function() return ns:SpecMenuItems() end, function(specKey)
            UI().spec = specKey
            UI().ramp = nil
            Refresh()
        end)
    page.spec:SetPoint("TOPLEFT", 0, -16)
    ns:SectionLabel(left, "Ramps"):SetPoint("TOPLEFT", 0, -56)
    local well = CreateFrame("Frame", nil, left)
    well:SetPoint("TOPLEFT", 0, -72)
    well:SetPoint("BOTTOMRIGHT", 0, 104)
    ns:Fill(well, theme.well)
    ns:Border(well, theme.border)
    page.list = ns:ScrollList(well)
    page.list:SetPoint("TOPLEFT", 1, -1)
    page.list:SetPoint("BOTTOMRIGHT", -1, 1)

    page.newName = ns:EditBox(left, LEFT_W - 70, 26)
    page.newName:SetPoint("BOTTOMLEFT", 0, 68)
    page.newName:SetPlaceholder("new ramp name")
    page.add = ns:Button(left, "Add", 62, 26, function()
        local name = (page.newName:GetText() or ''):match('^%s*(.-)%s*$')
        if name == '' then
            return
        end
        if ns:FindRamp(ns:SelectedSpec(), name) then
            SetStatus("There already is a ramp called " .. name, 'error')
            return
        end
        ns:GetRamps(ns:SelectedSpec())[name] = { steps = "3 | " .. name .. " soon | countdown\n0 | " .. name }
        UI().ramp = name
        page.newName:SetValue('')
        Refresh()
        SetStatus("Added " .. name .. ", write its steps and save", 'accent')
    end, true)
    page.add:SetPoint("LEFT", page.newName, "RIGHT", 8, 0)
    page.restore = ns:ConfirmButton(left, "Restore starter ramps", "Click again to restore", LEFT_W, 26, function()
        ns:RestoreStarterRamps(ns:SelectedSpec())
        Refresh()
        SetStatus("The starter ramps are back", 'accent')
    end)
    page.restore:SetPoint("BOTTOMLEFT", 0, 30)
    ns:Tooltip(page.restore, "Restore starter ramps", "Adds the ramps the addon comes with for this spec back, replacing ramps with the same name.")

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", RIGHT_X, 0)
    right:SetPoint("BOTTOMRIGHT")
    page.title = ns:Text(right, 15)
    page.title:SetPoint("TOPLEFT", 0, -2)
    page.summary = ns:Text(right, 10, theme.dim)
    page.summary:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -4)

    local spellLabel = ns:SectionLabel(right, "Spell id")
    spellLabel:SetPoint("TOPRIGHT", -150, -2)
    ns:HelpIcon(right, "Spell id", "The ramp's main spell: its icon, the spell MRT notes use for the ramp, and the cooldown " ..
        "that hides the ramp's reminders when that option is on. Notes name spells by id, so with this set a note line for " ..
        "that spell becomes this ramp."):SetPoint("LEFT", spellLabel, "RIGHT", 4, 0)
    page.spellId = ns:EditBox(right, 150, 24, function(text)
        local _, ramp = SelectedRamp()
        if ramp then
            ramp.spellId = tonumber(text)
            Refresh()
        end
    end)
    page.spellId:SetPoint("TOPRIGHT", 0, -16)
    page.spellId:SetPlaceholder("none")

    ns:SectionLabel(right, "Steps"):SetPoint("TOPLEFT", 0, -50)
    page.editor = ns:Segmented(right, {
        { text = "Form", value = 'form', tooltip = "A row per step." },
        { text = "Text", value = 'text', tooltip = "The steps as text, one per line: when | text | options." }
    }, 140, 22, function() return UI().rampEditor == 'text' and 'text' or 'form' end, SetEditor)
    page.editor:SetPoint("TOPRIGHT", 0, -44)
    local area = ns:TextArea(right, function()
        page.formDirty = true
        SetStatus("Not saved yet")
    end)
    area:SetPoint("TOPLEFT", 0, -70)
    area:SetPoint("BOTTOMRIGHT", 0, 150)
    page.steps = area.box
    page.stepsArea = area

    --The form, in the same place
    local form = CreateFrame("Frame", nil, right)
    form:SetPoint("TOPLEFT", 0, -70)
    form:SetPoint("BOTTOMRIGHT", 0, 150)
    ns:Fill(form, theme.well)
    ns:Border(form, theme.border)
    page.form = form
    ns:SectionLabel(form, "Before it lands"):SetPoint("TOPLEFT", 10, -8)
    ns:SectionLabel(form, "Message"):SetPoint("TOPLEFT", 184, -8)
    --Over the say boxes, which sit right of the message on one line
    page.sayHeader = ns:SectionLabel(form, "Say")
    page.sayHeader:SetPoint("TOPLEFT", form, "TOPRIGHT", -352, -8)
    page.formList = ns:ScrollList(form)
    page.formList:SetPoint("TOPLEFT", 6, -24)
    page.formList:SetPoint("BOTTOMRIGHT", -4, 4)
    page.formRows = {}
    page.addStep = ns:Button(page.formList.content, "+ Add step", 120, 26, function()
        page.formSteps = page.formSteps or {}
        CollectForm()
        table.insert(page.formSteps, { when = '0', unit = 's', text = '', say = '', setup = false, countdown = false })
        Edited()
        Refresh()
    end, true)

    page.save = ns:Button(right, "Save", 90, 26, function()
        local name, ramp = SelectedRamp()
        if not ramp then
            return
        end
        local text = page.steps:GetText()
        if UI().rampEditor ~= 'text' then
            CollectForm()
            text = StepsText(page.formSteps or {})
        end
        local steps, problem = ns:ParseRampSteps(text)
        if not steps then
            SetStatus(problem, 'error')
            return
        end
        ramp.steps = text
        page.steps:ClearFocus()
        page.formDirty = false
        page.formSteps = nil
        Refresh()
        SetStatus("Saved " .. name, 'accent')
    end, true)
    page.save:SetPoint("BOTTOMLEFT", 0, 116)
    page.status = ns:Text(right, 11, theme.dim)
    page.status:SetPoint("LEFT", page.save, "RIGHT", 10, 0)
    page.status:SetPoint("RIGHT", right, "RIGHT", -150, 0)
    page.delete = ns:ConfirmButton(right, "Delete ramp", "Click again to delete", 140, 26, function()
        local name = SelectedRamp()
        if name then
            ns:GetRamps(ns:SelectedSpec())[name] = nil
            UI().ramp = nil
            Refresh()
            SetStatus("Deleted " .. name)
        end
    end)
    page.delete:SetPoint("BOTTOMRIGHT", 0, 116)

    local help = ns:Text(right, 10, theme.dim)
    help:SetPoint("BOTTOMLEFT", 0, 0)
    help:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    help:SetHeight(100)
    help:SetWordWrap(true)
    help:SetJustifyV("TOP")
    help:SetText(STEPS_HELP)
end

local function RampRow(index)
    local row = page.rows[index]
    if not row then
        row = ns:ListRow(page.list.content, ROW_H)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 10, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.label:SetPoint("RIGHT", -8, 0)
        row:SetScript("OnClick", function(self)
            UI().ramp = self.name
            Refresh()
            SetStatus("")
        end)
        page.rows[index] = row
    end
    return row
end

function Refresh()
    local specKey = ns:SelectedSpec()
    page.spec:Refresh()
    local selected, ramp = SelectedRamp()
    for _, row in ipairs(page.rows) do
        row:Hide()
    end
    local y = -2
    for index, name in ipairs(ns:GetRampNames(specKey)) do
        local row = RampRow(index)
        local info = C_Spell.GetSpellInfo(ns:GetRamps(specKey)[name].spellId or name)
        row.icon:SetTexture(info and info.iconID or 134400)
        row.label:SetText(name)
        row.name = name
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", page.list.content, "RIGHT", 0, 0)
        row:SetSelected(name == selected)
        row:Show()
        y = y - ROW_H
    end
    page.list:SetContentHeight(-y + 2)
    if ramp then
        page.title:SetText(selected)
        page.summary:SetText(Summary(ramp))
        page.spellId:SetValue(ramp.spellId and tostring(ramp.spellId) or '')
        --The form and text show the saved steps, unless they were edited and not saved yet
        if page.formRamp ~= selected then
            page.formRamp, page.formDirty = selected, false
        end
        if not page.formDirty or not page.formSteps then
            page.steps:SetText(ramp.steps or '')
            page.formSteps = FormSteps(ramp.steps) or {}
        end
    else
        page.formSteps, page.formRamp, page.formDirty = {}, nil, false
        page.title:SetText("No ramps")
        page.summary:SetText("Add a ramp, or restore the starter ramps of this spec.")
        page.spellId:SetValue('')
        page.steps:SetText('')
    end
    for _, widget in ipairs({ page.save, page.delete, page.spellId }) do
        widget:SetAlpha(ramp and 1 or 0.4)
    end
    local formMode = UI().rampEditor ~= 'text'
    page.editor:Refresh()
    page.form:SetShown(formMode and ramp ~= nil)
    page.stepsArea:SetShown(not formMode)
    if formMode then
        RefreshForm()
    end
end

ns:RegisterPage('ramps', "Ramps", 3, Build, function()
    Refresh()
end, { icon = 'rail-ramps' })

--For tests
function ns:GetRampsPageWidgets()
    return page
end
