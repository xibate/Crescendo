local _, ns = ...

--The pull review window: what was left out because it was on cooldown, what never triggered and why, and what showed

local theme = ns.theme
local WIDTH, HEIGHT = 420, 360
local LINE_H = 18

local window

local function CreateReviewWindow()
    window = CreateFrame("Frame", "CrescendoReview", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("TOP", 0, -140)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    table.insert(UISpecialFrames, "CrescendoReview")
    ns:Fill(window, theme.window)
    ns:Border(window, theme.border)
    local accent = window:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetColorTexture(ns:GetAccent())
    window.title = ns:Text(window, 14)
    window.title:SetPoint("TOPLEFT", 14, -14)
    window.title:SetText("Pull review")
    window.title:SetTextColor(ns:GetAccent())
    window.subtitle = ns:Text(window, 11, theme.dim)
    window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -4)
    window.subtitle:SetPoint("RIGHT", window, "RIGHT", -40, 0)
    local close = ns:Button(window, "x", 22, 22, function() window:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)
    window.list = ns:ScrollList(window)
    window.list:SetPoint("TOPLEFT", 14, -56)
    window.list:SetPoint("BOTTOMRIGHT", -14, 48)
    window.lines = {}
    window.open = ns:Button(window, "Open plan", 110, 26, function()
        local review = window.review
        if review then
            local ui = ns.db.ui
            ui.boss = review.encounterId
            for diffId, difficulty in pairs(ns.difficulties) do
                if difficulty.slug == review.diffSlug then
                    ui.difficulty = diffId
                end
            end
            ui.ability = nil
            window:Hide()
            ns:OpenWindow('plans')
        end
    end, true)
    window.open:SetPoint("BOTTOMLEFT", 14, 12)
    window.hint = ns:Text(window, 10, theme.dim)
    window.hint:SetPoint("LEFT", window.open, "RIGHT", 10, 0)
    window.hint:SetPoint("RIGHT", window, "RIGHT", -14, 0)
    window.hint:SetText("Reopen it with /cres review. Turn it off on the General page.")
    window.hint:SetWordWrap(true)
end

local function Line(index)
    local line = window.lines[index]
    if not line then
        line = ns:Text(window.list.content, 11)
        line:SetPoint("RIGHT", window.list.content, "RIGHT", 0, 0)
        window.lines[index] = line
    end
    return line
end

function ns:OpenPullReview(review)
    review = review or ns.db.lastReview
    if not review then
        ns:WriteOutput("No pull to review yet")
        return
    end
    if not window then
        CreateReviewWindow()
    end
    window.review = review
    local boss = ns.bosses[review.encounterId]
    local difficultyName = review.diffSlug
    for _, difficulty in pairs(ns.difficulties) do
        if difficulty.slug == review.diffSlug then
            difficultyName = difficulty.name
        end
    end
    window.subtitle:SetText((boss and boss.name or "Boss") .. " " .. difficultyName .. "  ·  " ..
        (review.killed and "kill" or "wipe") .. " at " .. ns:FormatTime(review.duration) .. "  ·  " .. review.date)
    local r, g, b = ns:GetAccent()
    local rows = {}
    local function Section(title, color, items, format)
        if #items == 0 then
            return
        end
        table.insert(rows, { text = (title .. " (" .. #items .. ")"):upper(), color = theme.section, section = true })
        for _, item in ipairs(items) do
            table.insert(rows, { text = format(item), color = color })
        end
    end
    Section("Left out, on cooldown", { theme.error[1], theme.error[2], theme.error[3], 1 }, review.skipped, function(item)
        return ns:FormatTime(item.at) .. "  " .. tostring(item.entry)
    end)
    Section("Never triggered", { 1, 0.75, 0.3, 1 }, review.missed, function(item)
        return item.text .. "  |cff8a8a8a" .. item.why .. "|r"
    end)
    Section("Showed", { r, g, b, 0.9 }, review.shown, function(item)
        return ns:FormatTime(item.at) .. "  " .. tostring(item.entry)
    end)
    for _, line in ipairs(window.lines) do
        line:Hide()
    end
    local y = 0
    for index, row in ipairs(rows) do
        local line = Line(index)
        if row.section and index > 1 then
            y = y - 8
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 0, y)
        line:SetPoint("RIGHT", window.list.content, "RIGHT", 0, 0)
        line:SetFont(ns:GetFont(), row.section and 10 or 11, "")
        line:SetText(row.text)
        line:SetTextColor(unpack(row.color))
        line:Show()
        y = y - LINE_H
    end
    window.list:SetContentHeight(-y)
    window:Show()
end

--For tests
function ns:GetReviewWidgets()
    return window
end
