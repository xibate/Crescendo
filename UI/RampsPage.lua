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
    local area = ns:TextArea(right, function()
        SetStatus("Not saved yet")
    end)
    area:SetPoint("TOPLEFT", 0, -66)
    area:SetPoint("BOTTOMRIGHT", 0, 150)
    page.steps = area.box

    page.save = ns:Button(right, "Save", 90, 26, function()
        local name, ramp = SelectedRamp()
        if not ramp then
            return
        end
        local text = page.steps:GetText()
        local steps, problem = ns:ParseRampSteps(text)
        if not steps then
            SetStatus(problem, 'error')
            return
        end
        ramp.steps = text
        page.steps:ClearFocus()
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
        if not page.steps:HasFocus() then
            page.steps:SetText(ramp.steps or '')
        end
    else
        page.title:SetText("No ramps")
        page.summary:SetText("Add a ramp, or restore the starter ramps of this spec.")
        page.spellId:SetValue('')
        page.steps:SetText('')
    end
    for _, widget in ipairs({ page.save, page.delete, page.spellId }) do
        widget:SetAlpha(ramp and 1 or 0.4)
    end
end

ns:RegisterPage('ramps', "Ramps", 3, Build, function()
    Refresh()
end, { icon = 'rail-ramps' })

--For tests
function ns:GetRampsPageWidgets()
    return page
end
