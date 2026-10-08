--[[Initialization]]--
local _, ns = ...

--On encounter start, check the player spec, confirm its supported and calculate the real cooldown of spells according to haste
function ns:SetPlayerSpec()
    local specId
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        specId = C_SpecializationInfo.GetSpecializationInfo(C_SpecializationInfo.GetSpecialization())
    else
        specId = GetSpecializationInfo(GetSpecialization())
    end
    ns.specName = ns.specs[specId]
    ns.specSupported = ns.specName ~= nil
    if ns.specName then
        local haste = ns:GetPlayerHaste() / 100
        for spellId, spell in pairs(ns[ns.specName]['spells']) do
            --Start from the unmodified cooldowns every pull, otherwise the talent modifiers stack up on every encounter
            spell['unmodified'] = spell['unmodified'] or { ['cd'] = spell['cd'], ['baseCd'] = spell['baseCd'] }
            spell['cd'] = spell['unmodified']['cd']
            spell['baseCd'] = spell['unmodified']['baseCd']
            if spell['modifiers'] then
                for modifier, effect in pairs(spell['modifiers']) do
                    if ns:IsSpellKnown(modifier) then
                        if spell['baseCd'] then
                            ns[ns.specName]['spells'][spellId]['baseCd'] = ns[ns.specName]['spells'][spellId]['baseCd'] + effect
                        else
                            ns[ns.specName]['spells'][spellId]['cd'] = ns[ns.specName]['spells'][spellId]['cd'] + effect
                        end
                    end
                end
            end
            if spell['baseCd'] then
                ns[ns.specName]['spells'][spellId]['cd'] = tonumber(string.format('%.1f', (ns[ns.specName]['spells'][spellId]['baseCd']) / ( 1 + haste)))
            end
        end
    end
end

--Haste can be a secret value during encounters since Midnight, so the last readable value is kept and used instead
function ns:GetPlayerHaste()
    local haste = GetHaste()
    if ns:IsSecret(haste) then
        return ns.lastKnownHaste or 0
    end
    ns.lastKnownHaste = haste
    return haste
end

--IsPlayerSpell was moved to C_SpellBook, the old global only exists as a deprecated fallback
function ns:IsSpellKnown(spellId)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellId, Enum.SpellBookSpellBank.Player)
    end
    return IsPlayerSpell(spellId)
end

--Creates the assignments to be displayed, using info from the spec file. static assignments run on a fixed time and dynamic assignments depend on a charged spell cooldown
function ns:SetupTimings(event, encounterId, difficultyId)
    --ns:ResetDisplay() REPLACE THIS WITH A HIDE DISPLAYS IF YOU GO INTO COMBAT
    --Init fight assignments Table
    ns.fightAssignments = {}
    ns.abilityAnchors = {}
    ns.abilityTimings = {}
    ns.barSource = nil
    local rampTypesTable = ns[ns.specName]['rampTypes']()
    local cooldownsTable = ns[ns.specName]['cooldowns']
    local utilitiesTable = ns[ns.specName]['utilities']
    local assignmentsTable = rampTypesTable
    --Generate non-ramp assignment elements
    for id, spell in pairs(cooldownsTable) do
        local spellInfo = C_Spell.GetSpellInfo(id)
        if ZynxRampHelperDB.options.specs[ns.specName][spell] and spellInfo and spellInfo.iconID then
            assignmentsTable[spell] = {
                {
                    ['text'] = spell .. ' Soon',
                    ['icon'] = spellInfo.iconID,
                    ['offset'] = ZynxRampHelperDB.options.timerDuration,
                    ['showTimer'] = true
                },
                {
                    ['text'] = spell,
                    ['icon'] = spellInfo.iconID,
                    ['offset'] = 0
                }
            }
        end
    end
    for id, spell in pairs(utilitiesTable) do
        local spellInfo = C_Spell.GetSpellInfo(id)
        if ZynxRampHelperDB.options.specs[ns.specName][spell] and spellInfo and spellInfo.iconID then
            assignmentsTable[spell] = {
                {
                    ['text'] = spell .. ' Soon',
                    ['icon'] = spellInfo.iconID,
                    ['offset'] = ZynxRampHelperDB.options.timerDuration,
                    ['showTimer'] = true
                },
                {
                    ['text'] = spell,
                    ['icon'] = spellInfo.iconID,
                    ['offset'] = 0
                }
            }
        end
    end
    local noteAssignments = {}
    --If Read From Note mode is enabled, grab the current note text and format it
    if event == "ENCOUNTER_START" and ZynxRampHelperDB.options.readFromNote then
        local mrtNoteArray = {
            ZynxRampHelperDB.options.readFromNote        and _G.VMRT.Note.Text1 or "",
            ZynxRampHelperDB.options.mrtPersonalNote     and _G.VMRT.Note.SelfText or ""
        }
        local mrtNoteText = table.concat(mrtNoteArray, "\n")
                    :gsub("^%s+", "")
                    :gsub("%s+$", "")
                    :gsub("\n%s*\n", "\n")
        local activeNote = ns:ConvertNoteToTable(mrtNoteText, ns.specName, encounterId, ns.difficulties[difficultyId]['slug'])
        for spell, timings in pairs(activeNote) do
            local rampType = ns[ns.specName]['cooldowns'][tonumber(spell)] or ns[ns.specName]['ramps'][tonumber(spell)] or ns[ns.specName]['utilities'][tonumber(spell)]
            if rampType then
                local timingsString = ""
                for _, time in pairs(timings) do
                    timingsString = timingsString .. time .. '\n'
                end
                noteAssignments[rampType] = timingsString
            end
        end
    end
    for type, _ in pairs(assignmentsTable) do
        local fightTimings, savedTimings
        if event == "ENCOUNTER_START" then
            local difficultySlug = ns.difficulties[difficultyId]['slug']
            savedTimings = ZynxRampHelperDB[ns.specName][difficultySlug][tostring(encounterId)][type]
            if ZynxRampHelperDB.options.readFromNote then
                fightTimings = noteAssignments[type]
            else
                fightTimings = savedTimings
            end
        elseif ZynxRampHelperDB.testing.testMode then
            savedTimings = ZynxRampHelperDB[ns.specName].testTimers[type]
            fightTimings = savedTimings
        end
        --Lines like '@Spectral Coils #2' are tied to a boss ability bar instead of a time, see BossMods.lua. These
        --always come from the addon's own timings, also when the times are read from the MRT note
        for _, anchor in pairs(ns:ParseAbilityAnchors(savedTimings)) do
            anchor['type'] = type
            table.insert(ns.abilityAnchors, anchor)
        end
        fightTimings = ns:ConvertTimesToTable(fightTimings)
        for index, phaseTimings in pairs(fightTimings) do
            if not ns.fightAssignments[index] then
                ns.fightAssignments[index] = {
                    ['dynamic'] = {},
                    ['static'] = {}
                }
            end
            for _, timing in pairs(phaseTimings) do
                for _, assignment in pairs(assignmentsTable[type]) do
                    local assignmentTime = ns:CutDecimals(timing - assignment['offset'])
                    if assignmentTime >= 0 and ns:ShouldUseAssignment(assignment) then
                        local kind = assignment['dynamic'] and 'dynamic' or 'static'
                        if not ns.fightAssignments[index][kind][assignmentTime] then
                            ns.fightAssignments[index][kind][assignmentTime] = {}
                        end
                        table.insert(ns.fightAssignments[index][kind][assignmentTime], ns:CreateAssignment(assignment))
                    end
                end
            end
        end
    end
    ns.assignmentsTable = assignmentsTable
end

--In prerequisites only mode the final cooldown press of a ramp is left out
function ns:ShouldUseAssignment(assignment)
    return not ZynxRampHelperDB.options.preReqsOnly or assignment['preRequisite']
end

--Copies one step of a ramp into an assignment that can be shown during the fight
function ns:CreateAssignment(assignment)
    return {
        ['text'] = assignment['text'],
        ['icon'] = assignment['icon'],
        ['loaded'] = false,
        ['dynamic'] = assignment['dynamic'],
        ['spellId'] = assignment['spellId'],
        ['showTimer'] = assignment['showTimer'],
        ['tts'] = assignment['tts'] or nil
    }
end

--The time to show a dynamic assignment depends on how you are using the charges, this compares the potential cooldown of the spell with the remaining time before the assignment to see if it should be shown
function ns:ComputeDynamicAssignments(currentTime, phase)
    for time, assignmentSet in pairs(ns.fightAssignments[tostring(phase)]['dynamic']) do
        for index, assignment in pairs(assignmentSet) do
            if time >= currentTime and not assignment['loaded'] and ns:ShouldShowDynamic(assignment, time - currentTime) then
                ns:ShowAssignment(assignment)
                ns.fightAssignments[tostring(phase)]['dynamic'][time][index]['loaded'] = true
            end
        end
    end
end

--A dynamic assignment shows once the charges of its spell would need all the time that is left to come back
function ns:ShouldShowDynamic(assignment, timeLeft)
    local spellInfo = C_Spell.GetSpellCharges(assignment['spellId'])
    local timeUntilFullCharges
    if not spellInfo or ns:IsSecret(spellInfo.currentCharges) or ns:IsSecret(spellInfo.cooldownStartTime) or ns:IsSecret(spellInfo.cooldownDuration) then
        --Charges can't be read during the encounter, assume both are spent so the reminder shows early rather than late
        timeUntilFullCharges = 2 * ns:GetRealCooldown(ns.specName, assignment['spellId'])
    else
        local spellCd
        if spellInfo.currentCharges < 2 then
            spellCd = spellInfo.cooldownStartTime + spellInfo.cooldownDuration - GetTime()
        else
            spellCd = 0
        end
        timeUntilFullCharges = spellInfo.cooldownDuration
        if spellInfo.currentCharges == 1 then
            timeUntilFullCharges = timeUntilFullCharges + spellCd
        elseif spellInfo.currentCharges == 0 then
            timeUntilFullCharges = timeUntilFullCharges + spellCd + spellInfo.cooldownDuration
        end
    end
    return timeUntilFullCharges >= timeLeft
end

--Gets either the actual cooldown or the base cooldown of a spell depending on if haste as been computed
function ns:GetRealCooldown(spec, spellId)
    return ns[spec]['spells'][spellId]['cd'] or ns[spec]['spells'][spellId]['baseCd']
end

--Sets up the phase changing condition for the current fight
function ns:SetupPhaseChanges(phaseChangesTable)
    ns.phaseTimerData.phaseTriggerCounter = {}
    ns.phaseTimerData.phaseActivations = {}
    --Since Midnight addons can't read the combat log, phases come from BigWigs/DBM stages (main.lua) or /zrh phase <number>
    if not ns.combatLogAvailable then
        return
    end
    local phaseChanges = {}
    for phase, trigger in pairs(phaseChangesTable) do
        phaseChanges[phase] = ns:FormatPhaseChangeString(trigger)
    end
    ns.phaseEventsTrigger:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    ns.phaseTimerData.phaseActivations = phaseChanges
end

--Import the currently pasted note into the addon assignments for the selected boss on the given spec
function ns:ImportNote(specName)
    local fightId = ZynxRampHelperDB.import.fight
    local diffId = ZynxRampHelperDB.import.difficulty
    local importText = ZynxRampHelperDB.import.importText
    if fightId and diffId and importText then
        local diffSlug = ns.difficulties[diffId].slug
        local timers = ns:ConvertNoteToTable(importText, specName, fightId, diffSlug)
        for type, timings in pairs(ZynxRampHelperDB[specName][diffSlug][tostring(fightId)]) do
            ZynxRampHelperDB[specName][diffSlug][tostring(fightId)][type] = ns:KeepAbilityLines(timings)
        end
        local spellList = ns:GetFullSpellList(specName)
        for spell, timings in pairs(timers) do
            local selectedSpell = spellList[tonumber(spell)]
            if selectedSpell then
                local timingsString = ''
                for _, time in pairs(timings) do
                    timingsString = timingsString .. time .. '\n'
                end
                ZynxRampHelperDB[specName][diffSlug][tostring(fightId)][selectedSpell] = (ZynxRampHelperDB[specName][diffSlug][tostring(fightId)][selectedSpell] or '') .. timingsString
            end
        end
        ZynxRampHelperDB.import.importText = '';
        ns:WriteOutput('Successfully imported ' .. specName .. ' timings for ' .. ns.difficulties[diffId].name .. ' ' .. ns.bosses[fightId].name)
    end
end

--Default assignments only exist for some specs and bosses, returns an empty string when there are none
function ns:GetDefaultAssignments(specName, fightId, diffSlug)
    local defaults = ns[specName]['defaultAssignments']
    if defaults and defaults[fightId] and defaults[fightId]['assignments'][diffSlug] then
        return defaults[fightId]['assignments'][diffSlug]
    end
    return ""
end

--Grabs the default assignments from the Defaults folder and pastes them in the import box
function ns:PasteDefaultForSpecificBoss(specName)
    local fightId = ZynxRampHelperDB.import.fight
    local diffId = ZynxRampHelperDB.import.difficulty
    local diffSlug = ns.difficulties[diffId].slug
    local defaultText = ns:GetDefaultAssignments(specName, fightId, diffSlug)
    if defaultText == "" then
        ns:WriteOutput('There are currently no default assignments setup for ' .. specName .. ' on ' .. ns.difficulties[diffId].name .. ' ' .. ns.bosses[fightId].name)
    else
        defaultText = defaultText:gsub("PLAYER", GetUnitName("player", false))
        ZynxRampHelperDB.import.importText = defaultText
        ns:WriteOutput('Pasted default assignments for ' .. specName .. ' on ' .. ns.difficulties[diffId].name .. ' ' .. ns.bosses[fightId].name)
    end
end