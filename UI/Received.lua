local _, ns = ...

--Asks the player whether to import plans someone sent them (see Core/Comms.lua). One question at a time, the next one
--shows once this one is answered

local theme = ns.theme
local popup
local waiting = {}

local function Show()
    local next = waiting[1]
    if not next then
        popup:Hide()
        return
    end
    popup.title:SetText("Plans from " .. next.sender)
    popup.text:SetText(ns:DescribePlanImport(next.data) .. ".\n\nYour plans for those bosses are kept in History, so an import can be undone.")
    popup.more:SetText(#waiting > 1 and ((#waiting - 1) .. " more waiting") or "")
    popup:Show()
end

local function Answer(import)
    local answered = table.remove(waiting, 1)
    if answered and import then
        ns:ImportPlans(answered.data)
        ns:WriteOutput("Imported plans from " .. answered.sender .. ": " .. ns:DescribePlanImport(answered.data):gsub(", replaces yours", ""))
        ns:RefreshWindow()
    end
    Show()
end

local function CreatePopup()
    popup = CreateFrame("Frame", "CrescendoReceived", UIParent)
    popup:SetSize(420, 200)
    popup:SetPoint("TOP", 0, -140)
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    ns:Fill(popup, theme.window)
    ns:Border(popup, theme.borderStrong)
    local logo = popup:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("TOPLEFT", 14, -12)
    logo:SetTexture("Interface/Addons/Crescendo/Media/logo")
    popup.title = ns:Text(popup, 14)
    popup.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    popup.title:SetTextColor(ns:GetAccent())
    popup.text = ns:Text(popup, 12)
    popup.text:SetPoint("TOPLEFT", 16, -46)
    popup.text:SetPoint("BOTTOMRIGHT", -16, 52)
    popup.text:SetWordWrap(true)
    popup.text:SetJustifyV("TOP")
    popup.import = ns:Button(popup, "Import", 110, 28, function() Answer(true) end, true)
    popup.import:SetPoint("BOTTOMRIGHT", -16, 14)
    popup.decline = ns:Button(popup, "Not now", 100, 28, function() Answer(false) end)
    popup.decline:SetPoint("RIGHT", popup.import, "LEFT", -8, 0)
    popup.more = ns:Text(popup, 11, theme.dim)
    popup.more:SetPoint("BOTTOMLEFT", 16, 22)
end

--Queues the question for plans that arrived
function ns:AskToImport(sender, data)
    if not popup then
        CreatePopup()
    end
    table.insert(waiting, { sender = sender, data = data })
    if #waiting == 1 then
        Show()
    else
        popup.more:SetText((#waiting - 1) .. " more waiting")
    end
end

--For tests
function ns:GetReceivedPopup()
    return popup
end
