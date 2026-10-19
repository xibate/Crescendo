local _, ns = ...

--After a pull: which presses showed, which were left out because the spell was on cooldown, and which plan lines never
--triggered, with why: a stage that didn't come, or no boss mod bar that matched

--The name of the ability an ability line is for, as the boss's ability list writes it
local function AbilityName(anchor, encounterId)
    for _, ability in ipairs(ns.bossAbilities[encounterId] or {}) do
        if (anchor.spellId and ability.spellId == anchor.spellId) or (not anchor.spellId and ability.name:lower() == anchor.name) then
            return ability.name
        end
    end
    if anchor.spellId then
        local info = C_Spell.GetSpellInfo(anchor.spellId)
        return info and info.name or tostring(anchor.spellId)
    end
    return (anchor.name:gsub("^%l", string.upper))
end

local function StageList(keys)
    local list = {}
    for _, key in ipairs(keys) do
        table.insert(list, key)
    end
    return table.concat(list, ", ")
end

--{ encounterId, diffSlug, duration, killed, date, shown = { at, entry }, skipped = { at, entry }, missed = { text, why } }
--of the fight that is ending
function ns:BuildPullReview(encounterId, difficultyId, killed)
    local fight = ns.fight
    local difficulty = ns.difficulties[difficultyId]
    local review = {
        encounterId = encounterId, diffSlug = difficulty and difficulty.slug, killed = killed,
        duration = GetTime() - fight.start, date = date("%H:%M"), shown = {}, skipped = {}, missed = {}
    }
    for _, line in ipairs(fight.log or {}) do
        if line.press then
            table.insert(line.skipped and review.skipped or review.shown, { at = line.at, entry = line.entry or line.text })
        end
    end
    --Ability lines no bar matched
    for _, anchor in ipairs(ns.abilityAnchors or {}) do
        if not anchor.fired then
            local missing = {}
            for _, phase in ipairs(anchor.phaseList or {}) do
                if not fight.stagesSeen[phase] then
                    table.insert(missing, phase)
                end
            end
            local why
            if anchor.phaseList and #missing == #anchor.phaseList then
                why = "stage " .. StageList(missing) .. " didn't come"
            elseif anchor.counts or anchor.every then
                why = "none of its casts came"
            else
                why = "the boss mod showed no bar for it"
            end
            table.insert(review.missed, { text = AbilityName(anchor, encounterId) .. ": " .. anchor.entry, why = why })
        end
    end
    --Stage lines of stages that didn't come
    local stageLines = {}
    for phase, reminders in pairs(ns.plan or {}) do
        if phase ~= 'main' and not fight.stagesSeen[phase] then
            for _, reminder in ipairs(reminders) do
                local key = phase .. ':' .. tostring(reminder.entry)
                if reminder.press and not stageLines[key] then
                    stageLines[key] = true
                    table.insert(review.missed, { text = "Stage " .. phase .. ": " .. tostring(reminder.entry), why = "stage " .. phase .. " didn't come" })
                end
            end
        end
    end
    table.sort(review.missed, function(a, b) return a.text < b.text end)
    return review
end

--Shows the review after a pull when something was left out or never triggered, else says in chat that all went well
function ns:ShowPullReview(review)
    if not review or not review.diffSlug then
        return
    end
    ns.db.lastReview = review
    if not ns.db.options.review then
        return
    end
    if #review.skipped == 0 and #review.missed == 0 then
        if #review.shown > 0 then
            ns:WriteOutput("All " .. #review.shown .. " reminders of the pull showed")
        end
        return
    end
    ns:OpenPullReview(review)
end
