local _, ns = ...

--At a ready check in a raid, a line in chat with the plan for the boss about to be pulled, and what is wrong with it:
--no plan, names that aren't a ramp, spell or equipped trinket, spells that aren't talented, trinkets without a use, and
--uses that won't be ready in time on the recorded pull

--What a plan has and what is wrong with it: { times, abilities, problems = { text } }
function ns:CheckPlanForPull(specKey, diffSlug, encounterId)
    local text = ns:GetPlan(specKey, diffSlug, encounterId)
    local result = { times = 0, abilities = 0, problems = {} }
    if not text:find('%S') then
        table.insert(result.problems, "There is no plan for this boss")
        return result
    end
    local plan = ns:ParsePlan(text)
    result.times, result.abilities = #plan.times, #plan.abilities
    local checked = {}
    for _, list in ipairs({ plan.times, plan.abilities }) do
        for _, timing in ipairs(list) do
            local entry = timing.entry
            if not checked[entry:lower()] then
                checked[entry:lower()] = true
                local ramp = ns:FindRamp(specKey, entry)
                local trinket = not ramp and ns:FindTrinket(entry)
                if not ns:GetEntrySteps(specKey, entry) then
                    table.insert(result.problems, entry .. " isn't a ramp, a spell you know or an equipped trinket")
                elseif ramp then
                    if ramp.spellId and not ns:IsSpellKnown(ramp.spellId) then
                        local info = C_Spell.GetSpellInfo(ramp.spellId)
                        table.insert(result.problems, entry .. ": you don't have " .. (info and info.name or ramp.spellId) .. " talented")
                    end
                elseif trinket then
                    if not trinket.spellId then
                        table.insert(result.problems, (trinket.name or entry) .. " has no use effect")
                    end
                else
                    local info = C_Spell.GetSpellInfo(tonumber(entry) or entry)
                    if info and info.spellID and not ns:IsSpellKnown(info.spellID) then
                        table.insert(result.problems, (info.name or entry) .. " isn't talented")
                    end
                end
            end
        end
    end
    local record = ns:GetRecordingFor(encounterId, diffSlug)
    if record then
        local conflicts = ns:BuildTimeline(specKey, text, record, encounterId).conflicts
        if conflicts > 0 then
            table.insert(result.problems, conflicts .. (conflicts == 1 and " use" or " uses") .. " won't be ready in time on your recorded pull, see the Timeline")
        end
    end
    return result
end

--The ready check lines for the boss the player is about to pull, nil outside the raids or as another spec. With a boss,
--difficulty and spec, the lines for those
function ns:ReadyCheckLines(boss, difficultyId, specKey)
    if not boss then
        boss, difficultyId = ns:CurrentBoss()
    end
    specKey = specKey or ns:GetPlayerSpecKey()
    local difficulty = boss and ns.difficulties[difficultyId]
    if not boss or not specKey or not difficulty then
        return nil
    end
    local result = ns:CheckPlanForPull(specKey, difficulty.slug, boss)
    local parts = {}
    if result.times > 0 then
        table.insert(parts, result.times .. (result.times == 1 and " time" or " times"))
    end
    if result.abilities > 0 then
        table.insert(parts, result.abilities .. (result.abilities == 1 and " boss ability assignment" or " boss ability assignments"))
    end
    local lines = { ns.bosses[boss].name .. " " .. difficulty.name .. ", " .. ns.specNames[specKey] ..
        (#parts > 0 and (": " .. table.concat(parts, ", ")) or "") .. (#result.problems == 0 and ". All set." or ".") }
    for _, problem in ipairs(result.problems) do
        table.insert(lines, "|cffff5a4d!|r " .. problem)
    end
    return lines
end

local readyCheck = CreateFrame("Frame")
readyCheck:RegisterEvent("READY_CHECK")
readyCheck:SetScript("OnEvent", function()
    if not ns.db or not ns.db.options.readyCheck then
        return
    end
    for index, line in ipairs(ns:ReadyCheckLines() or {}) do
        if index == 1 then
            ns:WriteOutput(line)
        else
            print("   " .. line)
        end
    end
end)
