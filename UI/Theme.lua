local _, ns = ...

--Look of the addon's windows: dark warm panels, faint 1px borders, dimmed white text and one accent colour, in the style
--of EllesmereUI. With EllesmereUI installed its accent colour and font are used, so the windows match the rest of the UI
local theme = {
    window = { 0.069, 0.058, 0.047, 0.97 },
    panel = { 0.089, 0.080, 0.072, 1 },
    well = { 0.030, 0.023, 0.018, 0.6 },
    input = { 0.103, 0.095, 0.088, 0.9 },
    border = { 1, 1, 1, 0.06 },
    borderStrong = { 1, 1, 1, 0.22 },
    text = { 1, 1, 1, 0.9 },
    dim = { 1, 1, 1, 0.53 },
    section = { 1, 1, 1, 0.41 },
    error = { 1, 0.35, 0.3, 1 },
    accent = { 0.05, 0.82, 0.62 }
}
ns.theme = theme

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

--The accent colour: EllesmereUI's when it is installed and chosen, Crescendo's aqua, or a colour of the player's own
function ns:GetAccent()
    local options = ns.db and ns.db.options
    local source = options and options.accentSource or 'ellesmere'
    if source == 'custom' and type(options.accentColor) == 'table' then
        local color = options.accentColor
        return color.r or theme.accent[1], color.g or theme.accent[2], color.b or theme.accent[3]
    end
    local eui = source == 'ellesmere' and _G.EllesmereUI
    if type(eui) == 'table' then
        if type(eui.GetAccentColor) == 'function' then
            local ok, r, g, b = pcall(eui.GetAccentColor)
            if ok and type(r) == 'number' then
                return r, g, b
            end
        end
        local green = eui.ELLESMERE_GREEN
        if type(green) == 'table' and type(green.r) == 'number' then
            return green.r, green.g, green.b
        end
    end
    return theme.accent[1], theme.accent[2], theme.accent[3]
end

--Opens the game's colour picker on the accent colour; the colour is kept as it is picked, and put back on cancel
function ns:PickAccentColor(onChange)
    local options = ns.db.options
    local before = options.accentColor or { r = theme.accent[1], g = theme.accent[2], b = theme.accent[3] }
    local picker = _G.ColorPickerFrame
    if not (picker and picker.SetupColorPickerAndShow) then
        return
    end
    picker:SetupColorPickerAndShow({
        r = before.r, g = before.g, b = before.b, hasOpacity = false,
        swatchFunc = function()
            local r, g, b = picker:GetColorRGB()
            options.accentColor = { r = r, g = g, b = b }
            onChange()
        end,
        cancelFunc = function()
            options.accentColor = before
            onChange()
        end
    })
end

function ns:GetFont()
    local eui = _G.EllesmereUI
    if type(eui) == 'table' and type(eui.GetFontPath) == 'function' then
        local ok, path = pcall(eui.GetFontPath)
        if ok and type(path) == 'string' then
            return path
        end
    end
    return DEFAULT_FONT
end

local function Color(color, alpha)
    return color[1], color[2], color[3], alpha or color[4] or 1
end

--A solid colour filling a frame
function ns:Fill(frame, color, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetColorTexture(Color(color))
    texture:SetAllPoints()
    return texture
end

--A 1px border around a frame, made of four textures so it stays sharp. Returns a function that recolours it
function ns:Border(frame, color)
    local edges = {}
    local function Edge(pointA, pointB, horizontal)
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetPoint(pointA)
        edge:SetPoint(pointB)
        if horizontal then
            edge:SetHeight(1)
        else
            edge:SetWidth(1)
        end
        table.insert(edges, edge)
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)
    local function SetColor(r, g, b, a)
        for _, edge in ipairs(edges) do
            edge:SetColorTexture(r, g, b, a)
        end
    end
    SetColor(Color(color or theme.border))
    return SetColor
end

function ns:Text(parent, size, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(ns:GetFont(), size or 12, "")
    text:SetShadowColor(0, 0, 0, 0.8)
    text:SetShadowOffset(1, -1)
    text:SetTextColor(Color(color or theme.text))
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

--A small upper case section label
function ns:SectionLabel(parent, label)
    local text = ns:Text(parent, 10, theme.section)
    text:SetText(label:upper())
    return text
end

--A flat button with a faint border that lights up on hover. 'accent' gives it the accent colour, 'plain' no fill or
--border until it is hovered
function ns:Button(parent, label, width, height, onClick, accent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height or 24)
    local background = ns:Fill(button, theme.panel)
    local setBorder = ns:Border(button, theme.borderStrong)
    button.label = ns:Text(button, 11, theme.text, "CENTER")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    local function Paint(hover)
        if accent == 'plain' then
            background:SetColorTexture(1, 1, 1, hover and 0.06 or 0)
            setBorder(1, 1, 1, 0)
        elseif accent then
            local r, g, b = ns:GetAccent()
            background:SetColorTexture(r, g, b, hover and 0.32 or 0.2)
            setBorder(r, g, b, hover and 0.9 or 0.6)
        else
            background:SetColorTexture(Color(theme.panel, hover and 0.95 or 0.65))
            setBorder(1, 1, 1, hover and 0.35 or 0.2)
        end
        button.label:SetTextColor(1, 1, 1, hover and 1 or 0.75)
    end
    Paint(false)
    button:SetScript("OnEnter", function() Paint(true) end)
    button:SetScript("OnLeave", function() Paint(false) end)
    button:SetScript("OnClick", function(self)
        if onClick then
            onClick(self)
        end
    end)
    return button
end

--A one line input box. onCommit(text) runs when Enter is pressed or the box loses focus
function ns:EditBox(parent, width, height, onCommit)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, height or 24)
    box:SetAutoFocus(false)
    box:SetFont(ns:GetFont(), 12, "")
    box:SetTextColor(Color(theme.text))
    box:SetTextInsets(8, 8, 0, 0)
    ns:Fill(box, theme.input)
    box.setBorder = ns:Border(box, theme.borderStrong)
    local committed
    local function Commit(self)
        local text = self:GetText()
        if text ~= committed and onCommit then
            committed = text
            onCommit(text)
        end
    end
    function box:SetValue(text)
        committed = text or ''
        self:SetText(committed)
        if self.placeholderText then
            self.placeholder:SetShown(committed == '' and not self:HasFocus())
        end
    end
    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(committed or '')
        self:ClearFocus()
    end)
    box.placeholder = ns:Text(box, 12, theme.section)
    box.placeholder:SetPoint("LEFT", 8, 0)
    box.placeholder:Hide()
    local function UpdatePlaceholder(self)
        self.placeholder:SetShown(self.placeholderText ~= nil and (self:GetText() or '') == '' and not self:HasFocus())
    end
    --Dim text shown while the box is empty
    function box:SetPlaceholder(text)
        self.placeholderText = text
        self.placeholder:SetText(text or '')
        UpdatePlaceholder(self)
    end
    box:SetScript("OnTextChanged", UpdatePlaceholder)
    box:HookScript("OnEditFocusLost", function(self)
        self.setBorder(Color(theme.borderStrong))
        UpdatePlaceholder(self)
    end)
    box:SetScript("OnEditFocusGained", function(self)
        local r, g, b = ns:GetAccent()
        self.setBorder(r, g, b, 0.8)
        self.placeholder:Hide()
    end)
    return box
end

--A vertical list that scrolls with the mouse wheel. Put rows in list.content and call list:SetContentHeight
function ns:ScrollList(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local position = math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 40))
        self:SetVerticalScroll(position)
    end)
    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)
    function scroll:SetContentHeight(height)
        content:SetHeight(math.max(1, height))
        if (self:GetVerticalScroll() or 0) > (self:GetVerticalScrollRange() or 0) then
            self:SetVerticalScroll(0)
        end
    end
    return scroll
end

--A menu of choices under a frame. items are { text, icon, value, header } and onSelect(value) runs on a click.
--Only one menu is open at a time, it closes on a choice, on Escape or when the frame it belongs to hides
local menu
function ns:OpenMenu(anchor, items, onSelect)
    if not menu then
        menu = CreateFrame("Frame", "CrescendoMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        ns:Fill(menu, theme.window)
        ns:Border(menu, theme.borderStrong)
        menu.rows = {}
        table.insert(UISpecialFrames, "CrescendoMenu")
    end
    local width = math.max(anchor:GetWidth() or 180, 180)
    local widest = 0
    for _, row in ipairs(menu.rows) do
        row:Hide()
    end
    local y = -4
    for index, item in ipairs(items) do
        local row = menu.rows[index]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(22)
            row.highlight = ns:Fill(row, { 1, 1, 1, 0.08 }, "ARTWORK")
            row.highlight:Hide()
            row.icon = row:CreateTexture(nil, "OVERLAY")
            row.icon:SetSize(16, 16)
            row.icon:SetPoint("LEFT", 8, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.label = ns:Text(row, 11)
            row:SetScript("OnEnter", function(self) if not self.isHeader then self.highlight:Show() end end)
            row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
            menu.rows[index] = row
        end
        row:SetPoint("TOPLEFT", 1, y)
        row:SetPoint("TOPRIGHT", -1, y)
        row.isHeader = item.header
        row.label:ClearAllPoints()
        if item.icon then
            row.icon:SetTexture(item.icon)
            row.icon:Show()
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        else
            row.icon:Hide()
            row.label:SetPoint("LEFT", 8, 0)
        end
        row.label:SetPoint("RIGHT", -8, 0)
        row.label:SetText(item.header and item.text:upper() or item.text)
        widest = math.max(widest, (row.label:GetStringWidth() or 0) + (item.icon and 30 or 0) + 24)
        if item.header then
            row.label:SetTextColor(Color(theme.section))
            row:SetScript("OnClick", nil)
        else
            row.label:SetTextColor(Color(theme.text))
            row:SetScript("OnClick", function()
                menu:Hide()
                onSelect(item.value)
            end)
        end
        row:Show()
        y = y - 22
    end
    menu:SetSize(math.max(width, widest), -y + 4)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu.owner = anchor
    menu:Show()
    return menu
end

function ns:CloseMenu()
    if menu then
        menu:Hide()
    end
end

--A tooltip on hover. 'content' is a title with an optional text below it, or a function(tooltip, frame) that fills the
--tooltip and returns false to show none
function ns:Tooltip(frame, content, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if type(content) == 'function' then
            if content(GameTooltip, self) == false then
                GameTooltip:Hide()
                return
            end
        else
            GameTooltip:SetText(content, 1, 1, 1)
            if text then
                GameTooltip:AddLine(text, nil, nil, nil, true)
            end
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

--A small '?' that explains something on hover
function ns:HelpIcon(parent, title, text)
    local help = CreateFrame("Button", nil, parent)
    help:SetSize(14, 14)
    help.label = ns:Text(help, 10, theme.dim, "CENTER")
    help.label:SetPoint("CENTER")
    help.label:SetText("?")
    ns:Border(help, theme.borderStrong)
    help:SetScript("OnEnter", function() help.label:SetTextColor(ns:GetAccent()) end)
    help:SetScript("OnLeave", function() help.label:SetTextColor(Color(theme.dim)) end)
    ns:Tooltip(help, title, text)
    return help
end

--A selectable list row with an accent bar on the left when selected
function ns:ListRow(parent, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height or 26)
    row.background = ns:Fill(row, { 1, 1, 1, 0 }, "BACKGROUND")
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetWidth(2)
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.label = ns:Text(row, 12)
    function row:SetSelected(selected)
        self.selected = selected
        if selected then
            self.bar:SetColorTexture(ns:GetAccent())
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

--Buttons side by side of which one is selected, filled with the accent colour. get() returns the selected value and
--set(value) runs on a click
function ns:Segmented(parent, items, width, height, get, set)
    local group = CreateFrame("Frame", nil, parent)
    group:SetSize(width, height)
    ns:Fill(group, theme.input)
    ns:Border(group, theme.borderStrong)
    group.buttons = {}
    local buttonWidth = width / #items
    for index, item in ipairs(items) do
        local button = CreateFrame("Button", nil, group)
        button:SetSize(buttonWidth, height)
        button:SetPoint("TOPLEFT", (index - 1) * buttonWidth, 0)
        button.fill = button:CreateTexture(nil, "ARTWORK")
        button.fill:SetPoint("TOPLEFT", 1, -1)
        button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        button.label = ns:Text(button, 11, theme.text, "CENTER")
        button.label:SetPoint("CENTER")
        button.label:SetText(item.text)
        button.value = item.value
        if index > 1 then
            local divider = button:CreateTexture(nil, "BORDER")
            divider:SetWidth(1)
            divider:SetPoint("TOPLEFT", 0, -4)
            divider:SetPoint("BOTTOMLEFT", 0, 4)
            divider:SetColorTexture(Color(theme.borderStrong))
        end
        button:SetScript("OnClick", function()
            set(item.value)
            group:Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            if not self.selected then
                self.fill:SetColorTexture(1, 1, 1, 0.06)
            end
        end)
        button:SetScript("OnLeave", function() group:Refresh() end)
        if item.tooltip then
            ns:Tooltip(button, item.text, item.tooltip)
        end
        group.buttons[index] = button
    end
    function group:Refresh()
        local current = get()
        local r, g, b = ns:GetAccent()
        for _, button in ipairs(self.buttons) do
            button.selected = button.value == current
            if button.selected then
                button.fill:SetColorTexture(r, g, b, 0.9)
                button.label:SetTextColor(0.05, 0.05, 0.05, 1)
            else
                button.fill:SetColorTexture(0, 0, 0, 0)
                button.label:SetTextColor(1, 1, 1, 0.6)
            end
        end
    end
    group:Refresh()
    return group
end

--A button showing the current choice that opens a menu of choices. getText() gives the label, getItems() the menu items
--(see ns:OpenMenu) and onSelect(value) runs on a choice. style is passed on to ns:Button
function ns:Dropdown(parent, width, height, getText, getItems, onSelect, style)
    local dropdown = ns:Button(parent, "", width, height, nil, style)
    dropdown.label:ClearAllPoints()
    dropdown.label:SetPoint("LEFT", 10, 0)
    dropdown.label:SetPoint("RIGHT", -24, 0)
    dropdown.label:SetJustifyH("LEFT")
    local arrow = ns:Text(dropdown, 11, theme.dim, "RIGHT")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")
    dropdown:SetScript("OnClick", function(self)
        ns:OpenMenu(self, getItems(), function(value)
            onSelect(value)
            self:Refresh()
        end)
    end)
    function dropdown:Refresh()
        self.label:SetText(getText() or '')
    end
    dropdown:Refresh()
    return dropdown
end

--A box to tick. get() tells if it is ticked and set(ticked) runs on a click
function ns:Checkbox(parent, label, get, set, tooltip)
    local check = CreateFrame("Button", nil, parent)
    check:SetSize(260, 20)
    local box = CreateFrame("Frame", nil, check)
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    ns:Fill(box, theme.input)
    local setBorder = ns:Border(box, theme.borderStrong)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    check.label = ns:Text(check, 12)
    check.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    check.label:SetText(label)
    function check:Refresh()
        local ticked = get() and true or false
        self.checked = ticked
        local r, g, b = ns:GetAccent()
        mark:SetColorTexture(r, g, b, 1)
        mark:SetShown(ticked)
        if ticked then
            setBorder(r, g, b, 0.8)
        else
            setBorder(Color(theme.borderStrong))
        end
        self.label:SetTextColor(1, 1, 1, ticked and 0.95 or 0.7)
    end
    check:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    if tooltip then
        ns:Tooltip(check, label, tooltip)
    end
    check:Refresh()
    return check
end

local function RoundToStep(value, step)
    return math.floor(value / step + 0.5) * step
end

--A slider with its label above it and a box to type the exact value. get() gives the value and set(value) runs on a change
function ns:Slider(parent, label, width, min, max, step, get, set, tooltip)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 42)
    holder.label = ns:Text(holder, 11, theme.dim)
    holder.label:SetPoint("TOPLEFT", 0, -2)
    holder.label:SetText(label)
    local function Format(value)
        return step < 1 and string.format("%.1f", value) or tostring(math.floor(value + 0.5))
    end
    local function Apply(value)
        value = math.max(min, math.min(max, RoundToStep(value, step)))
        set(value)
        holder:Refresh()
    end
    holder.value = ns:EditBox(holder, 54, 18, function(text)
        local value = tonumber(text)
        if value then
            Apply(value)
        else
            holder:Refresh()
        end
    end)
    holder.value:SetPoint("TOPRIGHT", 0, 0)
    holder.value:SetJustifyH("RIGHT")
    holder.value:SetTextInsets(4, 6, 0, 0)
    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(14)
    slider:SetPoint("BOTTOMLEFT", 0, 2)
    slider:SetPoint("BOTTOMRIGHT", 0, 2)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(false)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetColorTexture(1, 1, 1, 0.1)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    slider:SetThumbTexture(thumb)
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    slider:SetScript("OnValueChanged", function(_, value, userInput)
        if userInput then
            Apply(value)
        end
    end)
    holder.slider = slider
    function holder:Refresh()
        local r, g, b = ns:GetAccent()
        thumb:SetColorTexture(r, g, b, 1)
        fill:SetColorTexture(r, g, b, 0.6)
        local value = get()
        slider:SetValue(value)
        self.value:SetValue(Format(value))
    end
    if tooltip then
        ns:Tooltip(holder.value, label, tooltip)
    end
    holder:Refresh()
    return holder
end

--A button that needs a second click within a few seconds, for things that can't be undone
function ns:ConfirmButton(parent, label, confirmLabel, width, height, onConfirm)
    local armedUntil = 0
    local button
    button = ns:Button(parent, label, width, height, function()
        if GetTime() <= armedUntil then
            armedUntil = 0
            button.label:SetText(label)
            button.label:SetTextColor(1, 1, 1, 0.75)
            onConfirm()
        else
            armedUntil = GetTime() + 4
            button.label:SetText(confirmLabel)
            button.label:SetTextColor(theme.error[1], theme.error[2], theme.error[3], 1)
            C_Timer.NewTimer(4, function()
                if GetTime() >= armedUntil then
                    button.label:SetText(label)
                    button.label:SetTextColor(1, 1, 1, 0.75)
                end
            end)
        end
    end)
    return button
end

--A multi-line text box in a scrolling well. onChange(text) runs when the player types
function ns:TextArea(parent, onChange)
    local well = CreateFrame("Frame", nil, parent)
    ns:Fill(well, theme.input)
    ns:Border(well, theme.borderStrong)
    local scroll = CreateFrame("ScrollFrame", nil, well)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFont(ns:GetFont(), 12, "")
    box:SetTextColor(Color(theme.text))
    box:SetWidth(200)
    scroll:SetScrollChild(box)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 40)))
    end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        box:SetWidth(width)
    end)
    --Keeps the cursor in view while typing
    box:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local top = -y
        local position = scroll:GetVerticalScroll() or 0
        local visible = scroll:GetHeight() or 0
        if top < position then
            scroll:SetVerticalScroll(top)
        elseif top + height > position + visible then
            scroll:SetVerticalScroll(top + height - visible)
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and onChange then
            onChange(self:GetText())
        end
    end)
    well:EnableMouse(true)
    well:SetScript("OnMouseDown", function() box:SetFocus() end)
    well.box = box
    return well
end

--A tab like a small bordered label, filled with the accent colour when selected. SetSelected shows which it is
function ns:Chip(parent, label, onClick)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(24)
    chip.fill = ns:Fill(chip, { 1, 1, 1, 0 })
    chip.setBorder = ns:Border(chip, theme.border)
    chip.label = ns:Text(chip, 11, theme.dim, "CENTER")
    chip.label:SetPoint("CENTER")
    function chip:SetLabel(text)
        self.label:SetText(text)
        self:SetWidth(math.floor((self.label:GetStringWidth() or 40) + 24))
    end
    local function Paint(hover)
        local r, g, b = ns:GetAccent()
        if chip.selected then
            chip.fill:SetColorTexture(r, g, b, 0.9)
            chip.setBorder(r, g, b, 0.9)
            chip.label:SetTextColor(0.05, 0.05, 0.05, 1)
        else
            chip.fill:SetColorTexture(1, 1, 1, hover and 0.05 or 0)
            chip.setBorder(1, 1, 1, hover and 0.3 or 0.12)
            chip.label:SetTextColor(1, 1, 1, hover and 0.9 or 0.6)
        end
    end
    function chip:SetSelected(selected)
        self.selected = selected
        Paint(false)
    end
    chip:SetScript("OnEnter", function() Paint(true) end)
    chip:SetScript("OnLeave", function() Paint(false) end)
    chip:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    chip:SetLabel(label or '')
    chip:SetSelected(false)
    return chip
end

--A section heading that folds the rows under it away when clicked, with + or - in front. SetFolded shows which it is
function ns:FoldHeader(parent, height)
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(height or 22)
    header.background = ns:Fill(header, { 1, 1, 1, 0 })
    header.sign = ns:Text(header, 12, theme.section, "CENTER")
    header.sign:SetPoint("LEFT", 4, 0)
    header.sign:SetWidth(12)
    header.label = ns:Text(header, 10, theme.section)
    header.label:SetPoint("LEFT", 20, 0)
    header.label:SetPoint("RIGHT", -6, 0)
    local function Paint(hover)
        header.background:SetColorTexture(1, 1, 1, hover and 0.05 or 0)
        local alpha = hover and 0.85 or (header.highlighted and 0.75 or theme.section[4])
        header.label:SetTextColor(1, 1, 1, alpha)
        header.sign:SetTextColor(1, 1, 1, alpha)
    end
    header:SetScript("OnEnter", function() Paint(true) end)
    header:SetScript("OnLeave", function() Paint(false) end)
    function header:SetFolded(folded)
        self.folded = folded
        self.sign:SetText(folded and "+" or "-")
    end
    --A folded section with the selection in it is a little brighter, so the selection can be found
    function header:SetHighlighted(highlighted)
        self.highlighted = highlighted
        Paint(false)
    end
    header:SetFolded(false)
    return header
end
