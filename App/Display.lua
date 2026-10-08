--[[Initialization]]--
local _, ns = ...

--Create a new display frame
function ns:CreateDisplayFrame(num)
    ns.frames[num] = CreateFrame("FRAME", nil, UIParent)
    ns.frames[num]:SetSize(1, 1)
    ns.frames[num]:SetHeight(1)
    if num == 1 then
        ns.frames[num]:SetPoint("CENTER", ZynxRampHelperDB.options.framePositionX, ZynxRampHelperDB.options.framePositionY)
    else
        local points = ns:GetAttachmentPoints()
        ns.frames[num]:SetPoint(points.child, ns.frames[num - 1], points.parent, points.xSpacing, points.ySpacing)
    end
    ns.frames[num]:SetFrameStrata("TOOLTIP")
    ns.frames[num].icon = ns.frames[num]:CreateTexture(nil, "OVERLAY") --Icon that will be displayed
    ns.frames[num].icon:SetPoint("CENTER", ns.frames[num], "CENTER", 0, 0) --Attached to the info frame, in the center
    ns.frames[num].icon:SetSize(ZynxRampHelperDB.options.iconSizeW, ZynxRampHelperDB.options.iconSizeH)
    ns.frames[num].text = ns.frames[num]:CreateFontString(nil, "OVERLAY", "GameFontHighlight") --Text is the text that will be displayed
    ns.frames[num].text:SetPoint("TOP", ns.frames[num].icon, "BOTTOM") --Attach the top of the text to the bottom of the icon
    ns.frames[num].text:SetShadowColor(0, 0, 0, 1)
    ns.frames[num].text:SetShadowOffset(-2, -2)
    ns.frames[num].text:SetScale(ZynxRampHelperDB.options.textSize)
    ns.frames[num].timer = ns.frames[num]:CreateFontString(nil, "OVERLAY", "GameFontHighlight") --Timer to be shown for the assignments marked with showTimer
    ns.frames[num].timer:SetPoint("CENTER", ns.frames[num].icon, "CENTER") --Attached to the icon, in the center
    ns.frames[num].timer:SetShadowColor(0, 0, 0, 1)
    ns.frames[num].timer:SetShadowOffset(-2, -2)
    ns.frames[num].timer:SetScale(ZynxRampHelperDB.options.timerSize)
    ns.frames[num].busy = false
end

--Get an available display
function ns:GetFreeDisplayIndex()
    local foundFrame = false
    local currentIndex = 1
    while not foundFrame do
        if ns.frames[currentIndex] then
            if not ns.frames[currentIndex].busy then
                foundFrame = true
                return currentIndex
            end
        else
            ns:CreateDisplayFrame(currentIndex)
            foundFrame = true
            return currentIndex
        end
        currentIndex = currentIndex + 1
    end
end

--Showing an assignment involved updating the icon and text of the infoFrame, and sending the text as TTS. The timer is shown if the assignment has the showTimer flag set to true
function ns:ShowAssignment(assignment)
    local frameIndex = ns:GetFreeDisplayIndex()
    ns.frames[frameIndex].text:SetText(assignment['text'])
    ns.frames[frameIndex].icon:SetTexture(assignment['icon'])
    ns.frames[frameIndex].busy = true
    ns:SendTts(assignment['tts'] or assignment['text'])
    local showTimer = nil
    if assignment['showTimer'] then
        local hideTime = GetTime() + 3
        showTimer = C_Timer.NewTicker(0.01, function()
            ns.frames[frameIndex].timer:SetText((string.format('%.1f', hideTime - GetTime())))
        end)
    end
    C_Timer.NewTimer(3, function()
        ns.frames[frameIndex].text:SetText("")
        ns.frames[frameIndex].icon:SetTexture(nil)
        ns.frames[frameIndex].busy = false
        if showTimer then
            showTimer:Cancel()
            ns.frames[frameIndex].timer:SetText("")
        end
    end)
end

--Re init display in case settings changed
function ns:ResetDisplay()
    if ns.frames[1] then
        ns.frames[1]:SetPoint("CENTER", ZynxRampHelperDB.options.framePositionX, ZynxRampHelperDB.options.framePositionY)
    end
    local points = ns:GetAttachmentPoints()
    for index, _ in pairs(ns.frames) do
        ns.frames[index].text:SetScale(ZynxRampHelperDB.options.textSize)
        ns.frames[index].icon:SetSize(ZynxRampHelperDB.options.iconSizeW, ZynxRampHelperDB.options.iconSizeH)
        ns.frames[index].timer:SetScale(ZynxRampHelperDB.options.timerSize)
        if not (index == 1) then
            ns.frames[index]:ClearAllPoints()
            ns.frames[index]:SetPoint(points.child, ns.frames[index - 1], points.parent, points.xSpacing, points.ySpacing)
        end
    end
end

--Sends a TTS message with some predefined parameters
function ns:SendTts(text)
    if ZynxRampHelperDB.options.ttsEnabled then
        --The destination argument was removed from SpeakText, the enum it used no longer exists
        C_VoiceChat.SpeakText(ZynxRampHelperDB.options.ttsVoice, text, ZynxRampHelperDB.options.ttsRate, ZynxRampHelperDB.options.ttsVolume)
    end
end

--Outputs and error message to chat. This is our choice instead of making the addon crash and stop working
function ns:WriteOutput(text)
    print('|cffff680aZynx Ramp Helper:|r ' .. text)
end

--Toggles the first three displays for debugging mode
function ns:ToggleDisplay()
    local showing = ZynxRampHelperDB.options.toggleDisplay
    local text, icon, timer, busy
    if showing then
        text, icon, timer, busy = '', 0, '', false
        ZynxRampHelperDB.options.toggleDisplay = false
    else
        text, icon, timer, busy = 'Ramp Helper', 450907, '2.3', true
        ZynxRampHelperDB.options.toggleDisplay = true
    end
    for i = 1, 3 do
        if not ns.frames[i] then
            ns:CreateDisplayFrame(i)
        end
        ns.frames[i].text:SetText(text)
        ns.frames[i].icon:SetTexture(icon)
        ns.frames[i].timer:SetText(timer)
        ns.frames[i].busy = busy
    end
end

--Get the attachment points depending on current settings
function ns:GetAttachmentPoints()
    local childPoint, parentPoint, xSpacing, ySpacing = '', '', 0, 0
    if ZynxRampHelperDB.options.growDirection == 'top' then
        childPoint = "BOTTOM"
        parentPoint = "TOP"
        ySpacing = ZynxRampHelperDB.options.displaySpacing
    elseif ZynxRampHelperDB.options.growDirection == 'bottom' then
        childPoint = "TOP"
        parentPoint = "BOTTOM"
        ySpacing = ZynxRampHelperDB.options.displaySpacing * -1
    elseif ZynxRampHelperDB.options.growDirection == 'left' then
        childPoint = "RIGHT"
        parentPoint = "LEFT"
        xSpacing = ZynxRampHelperDB.options.displaySpacing * -1
    elseif ZynxRampHelperDB.options.growDirection == 'right' then
        childPoint = "LEFT"
        parentPoint = "RIGHT"
        xSpacing = ZynxRampHelperDB.options.displaySpacing
    end
    return {
        ['child'] = childPoint,
        ['parent'] = parentPoint,
        ['xSpacing'] = xSpacing,
        ['ySpacing'] = ySpacing
    }
end