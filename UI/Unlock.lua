local _, ns = ...

--Unlock mode, like EllesmereUI's: the screen dims under a grid, the reminders and the Next up strip show as a preview
--with a box over each that can be dragged, and a small toolbar sets the exact position of the one picked last, snaps to
--the grid and locks them again. Escape and entering combat lock them too

local theme = ns.theme
local GRID = 32
local SNAP = 8

local overlay, toolbar
local movers = {}
local selected = 'reminders'
local unlocked = false
local previewWasOn = false
local windowWasOpen = false

local function Options()
    return ns.db.options
end

local function Round(value, step)
    return math.floor(value / step + 0.5) * step
end

--What can be moved: the options its position is kept in, its size, and what puts it there
local MOVABLE = {
    {
        key = 'reminders', label = "Ramp reminders", x = 'framePositionX', y = 'framePositionY',
        size = function() return Options().iconSizeW + 2, Options().iconSizeH + 2 end,
        apply = function() ns:ResetDisplay() end
    },
    {
        key = 'nextUp', label = "Next up", x = 'nextUpX', y = 'nextUpY',
        size = function() return ns:NextUpSize() end,
        apply = function() ns:ResetNextUp() end,
        shown = function() return Options().nextUp end
    }
}

local function Movable(key)
    for _, movable in ipairs(MOVABLE) do
        if movable.key == key then
            return movable
        end
    end
end

--Moves something to a position, in pixels from the middle of the screen, snapped to the grid when that is on
function ns:SetMoverPosition(key, x, y)
    local movable = Movable(key)
    local step = Options().snapToGrid and SNAP or 1
    Options()[movable.x] = Round(x, step)
    Options()[movable.y] = Round(y, step)
    movable.apply()
    if unlocked then
        ns:RefreshUnlock()
    end
end

function ns:SetDisplayPosition(x, y)
    ns:SetMoverPosition('reminders', x, y)
end

local function SelectedPosition()
    local movable = Movable(selected)
    return Options()[movable.x], Options()[movable.y]
end

local function DrawGrid(frame)
    local width = UIParent:GetWidth() or 1920
    local height = UIParent:GetHeight() or 1080
    local function Line(vertical, offset, alpha, thickness)
        local line = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        if vertical then
            line:SetWidth(thickness)
            line:SetPoint("TOP", frame, "TOP", offset, 0)
            line:SetPoint("BOTTOM", frame, "BOTTOM", offset, 0)
        else
            line:SetHeight(thickness)
            line:SetPoint("LEFT", frame, "LEFT", 0, offset)
            line:SetPoint("RIGHT", frame, "RIGHT", 0, offset)
        end
        line:SetColorTexture(1, 1, 1, alpha)
        return line
    end
    for offset = GRID, width / 2, GRID do
        Line(true, offset, 0.06, 1)
        Line(true, -offset, 0.06, 1)
    end
    for offset = GRID, height / 2, GRID do
        Line(false, offset, 0.06, 1)
        Line(false, -offset, 0.06, 1)
    end
    local r, g, b = ns:GetAccent()
    Line(true, 0, 0.5, 1):SetColorTexture(r, g, b, 0.5)
    Line(false, 0, 0.5, 1):SetColorTexture(r, g, b, 0.5)
end

--A box over something that can be moved, dragged to move it. Clicking or dragging it picks it for the toolbar
local function CreateMover(movable)
    local mover = CreateFrame("Button", "CrescendoMover" .. (movable.key == 'reminders' and "" or movable.key), UIParent)
    mover:SetFrameStrata("TOOLTIP")
    mover:SetFrameLevel(100)
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover.fill = ns:Fill(mover, { 1, 1, 1, 0.12 })
    mover.setBorder = ns:Border(mover, theme.borderStrong)
    mover.label = ns:Text(mover, 11, theme.text, "CENTER")
    mover.label:SetPoint("BOTTOM", mover, "TOP", 0, 6)
    mover.label:SetText(movable.label)
    mover.key = movable.key
    local function Paint(active)
        local r, g, b = ns:GetAccent()
        local picked = selected == movable.key
        mover.fill:SetColorTexture(r, g, b, (active and 0.35) or (picked and 0.24) or 0.12)
        mover.setBorder(r, g, b, (active or picked) and 1 or 0.55)
    end
    mover.Paint = Paint
    mover:SetScript("OnEnter", function() Paint(true) end)
    mover:SetScript("OnLeave", function() if not mover.dragging then Paint(false) end end)
    local function Pick()
        selected = movable.key
        ns:RefreshUnlock()
    end
    mover:SetScript("OnClick", Pick)
    --While dragging, the frame follows the box
    local function Follow()
        local x, y = mover:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and parentX then
            Options()[movable.x] = Round(x - parentX, 1)
            Options()[movable.y] = Round(y - parentY, 1)
            movable.apply()
            toolbar.x:SetValue(tostring(Options()[movable.x]))
            toolbar.y:SetValue(tostring(Options()[movable.y]))
        end
    end
    mover:SetScript("OnDragStart", function(self)
        selected = movable.key
        self.dragging = true
        self:StartMoving()
        self:SetScript("OnUpdate", Follow)
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        self.dragging = false
        Follow()
        ns:SetMoverPosition(movable.key, Options()[movable.x], Options()[movable.y])
        Paint(false)
    end)
    ns:Tooltip(mover, movable.label, "Drag to move it. Click it to set its exact position in the toolbar.")
    movers[movable.key] = mover
end

local function Nudge(dx, dy)
    return function()
        local step = Options().snapToGrid and SNAP or 1
        local x, y = SelectedPosition()
        ns:SetMoverPosition(selected, x + dx * step, y + dy * step)
    end
end

local function CreateToolbar()
    toolbar = CreateFrame("Frame", "CrescendoUnlockBar", UIParent)
    toolbar:SetSize(760, 40)
    toolbar:SetPoint("TOP", 0, -120)
    toolbar:SetFrameStrata("TOOLTIP")
    toolbar:SetFrameLevel(110)
    toolbar:EnableMouse(true)
    toolbar:SetMovable(true)
    toolbar:SetClampedToScreen(true)
    toolbar:RegisterForDrag("LeftButton")
    toolbar:SetScript("OnDragStart", toolbar.StartMoving)
    toolbar:SetScript("OnDragStop", toolbar.StopMovingOrSizing)
    ns:Fill(toolbar, theme.window)
    ns:Border(toolbar, theme.borderStrong)
    local accentBar = toolbar:CreateTexture(nil, "ARTWORK")
    accentBar:SetHeight(2)
    accentBar:SetPoint("TOPLEFT", 1, -1)
    accentBar:SetPoint("TOPRIGHT", -1, -1)
    accentBar:SetColorTexture(ns:GetAccent())

    local title = ns:Text(toolbar, 12)
    title:SetPoint("LEFT", 12, 0)
    title:SetText("Unlocked")
    title:SetTextColor(ns:GetAccent())
    toolbar.picked = ns:Text(toolbar, 11, theme.text)
    toolbar.picked:SetPoint("LEFT", title, "RIGHT", 8, 0)
    toolbar.picked:SetWidth(110)

    local function Coordinate(label, anchor, key)
        local text = ns:Text(toolbar, 11, theme.dim)
        text:SetPoint("LEFT", anchor, "RIGHT", 14, 0)
        text:SetText(label)
        local box = ns:EditBox(toolbar, 52, 22, function(value)
            local number = tonumber(value)
            if number then
                local x, y = SelectedPosition()
                if key == 'x' then
                    x = number
                else
                    y = number
                end
                ns:SetMoverPosition(selected, x, y)
            else
                ns:RefreshUnlock()
            end
        end)
        box:SetPoint("LEFT", text, "RIGHT", 6, 0)
        return box
    end
    toolbar.x = Coordinate("X", toolbar.picked, 'x')
    toolbar.y = Coordinate("Y", toolbar.x, 'y')

    local previous = toolbar.y
    toolbar.nudges = {}
    for _, nudge in ipairs({ { "<", -1, 0, "Left" }, { ">", 1, 0, "Right" }, { "^", 0, 1, "Up" }, { "v", 0, -1, "Down" } }) do
        local button = ns:Button(toolbar, nudge[1], 22, 22, Nudge(nudge[2], nudge[3]))
        button:SetPoint("LEFT", previous, "RIGHT", previous == toolbar.y and 12 or 2, 0)
        ns:Tooltip(button, "Move " .. nudge[4], "One pixel, or one grid step with snap to grid on.")
        toolbar.nudges[nudge[4]] = button
        previous = button
    end

    toolbar.snap = ns:Checkbox(toolbar, "Snap to grid", function() return Options().snapToGrid end, function(value)
        Options().snapToGrid = value
        if value then
            for _, movable in ipairs(MOVABLE) do
                ns:SetMoverPosition(movable.key, Options()[movable.x], Options()[movable.y])
            end
        end
    end)
    toolbar.snap:SetWidth(100)
    toolbar.snap:SetPoint("LEFT", previous, "RIGHT", 12, 0)

    toolbar.lock = ns:Button(toolbar, "Lock", 64, 24, function() ns:SetUnlocked(false) end, true)
    toolbar.lock:SetPoint("RIGHT", -8, 0)
    toolbar.center = ns:Button(toolbar, "Center", 64, 24, function() ns:SetMoverPosition(selected, 0, 0) end)
    toolbar.center:SetPoint("RIGHT", toolbar.lock, "LEFT", -6, 0)
    ns:Tooltip(toolbar.center, "Center", "Moves the picked one to the middle of the screen.")
end

local function CreateOverlay()
    overlay = CreateFrame("Frame", "CrescendoUnlock", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("BACKGROUND")
    ns:Fill(overlay, { 0, 0, 0, 0.45 })
    DrawGrid(overlay)
    overlay:SetScript("OnHide", function()
        if unlocked then
            ns:SetUnlocked(false)
        end
    end)
    overlay:RegisterEvent("PLAYER_REGEN_DISABLED")
    overlay:SetScript("OnEvent", function()
        if unlocked then
            ns:WriteOutput("Locked the reminders for combat")
            ns:SetUnlocked(false)
        end
    end)
    table.insert(UISpecialFrames, "CrescendoUnlock")
    for _, movable in ipairs(MOVABLE) do
        CreateMover(movable)
    end
    CreateToolbar()
end

--Puts a box over each thing that can be moved, and the position of the picked one in the toolbar
function ns:RefreshUnlock()
    if not toolbar then
        return
    end
    local options = Options()
    if Movable(selected).shown and not Movable(selected).shown() then
        selected = 'reminders'
    end
    for _, movable in ipairs(MOVABLE) do
        local mover = movers[movable.key]
        local shown = unlocked and (not movable.shown or movable.shown())
        mover:SetShown(shown)
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "CENTER", options[movable.x], options[movable.y])
        mover:SetSize(movable.size())
        mover.Paint(false)
    end
    local x, y = SelectedPosition()
    toolbar.picked:SetText(Movable(selected).label)
    toolbar.x:SetValue(tostring(x))
    toolbar.y:SetValue(tostring(y))
    toolbar.snap:Refresh()
end

function ns:IsUnlocked()
    return unlocked
end

--Turns unlock mode on or off. The addon's window closes while it is on and opens again after
function ns:SetUnlocked(on)
    if on == unlocked then
        return
    end
    if on and InCombatLockdown and InCombatLockdown() then
        ns:WriteOutput("The reminders can't be unlocked in combat")
        return
    end
    unlocked = on
    if on then
        if not overlay then
            CreateOverlay()
        end
        previewWasOn = Options().toggleDisplay
        if not previewWasOn then
            ns:ToggleDisplay()
        end
        local window = ns:GetWindow()
        windowWasOpen = window and window.frame:IsShown()
        if windowWasOpen then
            window.frame:Hide()
        end
        overlay:Show()
        toolbar:Show()
        ns:RefreshUnlock()
    else
        overlay:Hide()
        for _, mover in pairs(movers) do
            mover:Hide()
        end
        toolbar:Hide()
        if not previewWasOn and Options().toggleDisplay then
            ns:ToggleDisplay()
        end
        if windowWasOpen then
            ns:OpenWindow('display')
        end
        ns:OnRemindersPlaced()
    end
end

function ns:ToggleUnlocked()
    ns:SetUnlocked(not unlocked)
end

--For tests
function ns:GetUnlockWidgets()
    return { overlay = overlay, mover = movers.reminders, movers = movers, toolbar = toolbar }
end
