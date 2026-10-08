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

function ns:GetAccent()
    local eui = _G.EllesmereUI
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

--A flat button with a faint border that lights up on hover. 'accent' gives it the accent colour
function ns:Button(parent, label, width, height, onClick, accent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height or 24)
    local background = ns:Fill(button, theme.panel)
    local setBorder = ns:Border(button, theme.borderStrong)
    button.label = ns:Text(button, 11, theme.text, "CENTER")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    local function Paint(hover)
        if accent then
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
    box:SetScript("OnEditFocusGained", function(self)
        local r, g, b = ns:GetAccent()
        self.setBorder(r, g, b, 0.8)
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
        menu = CreateFrame("Frame", "ZynxRampHelperMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        ns:Fill(menu, theme.window)
        ns:Border(menu, theme.borderStrong)
        menu.rows = {}
        table.insert(UISpecialFrames, "ZynxRampHelperMenu")
    end
    local width = math.max(anchor:GetWidth() or 180, 180)
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
    menu:SetSize(width, -y + 4)
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
