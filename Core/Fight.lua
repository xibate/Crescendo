local _, ns = ...

--State of the current fight: running, specKey, encounterId (nil in a test), start time, the phase key and start time of
--the current phase, and for a test what it tests (see Core/Test.lua)
ns.fight = { running = false }

function ns:StartFight(specKey, encounterId)
    ns:StopFight()
    ns.fight = {
        running = true,
        specKey = specKey,
        encounterId = encounterId,
        start = GetTime(),
        log = {},
        stagesSeen = { ['1'] = true }
    }
    ns.fight.ticker = C_Timer.NewTicker(0.5, function()
        ns:UpdateFight()
    end)
end

function ns:StopFight()
    local fight = ns.fight
    if fight.ticker then
        fight.ticker:Cancel()
    end
    ns.fight = { running = false }
    if fight.test then
        for _, timer in ipairs(fight.test.timers) do
            timer:Cancel()
        end
        ns:OnTestChanged()
    end
end

--A boss mod reported a stage, or it was started by hand. Its reminders are timed from now, and run again when the boss
--returns to a phase it was in before
function ns:StartPhase(phase)
    phase = ns:PhaseKey(phase)
    for _, reminder in ipairs(ns.plan[phase] or {}) do
        reminder.shown = false
    end
    ns.fight.phase = phase
    ns.fight.phaseStart = GetTime()
    if ns.fight.stagesSeen then
        ns.fight.stagesSeen[phase] = true
    end
end

--Starts a phase from the /cres phase <number> command, for when no boss mod is installed to report the phases
function ns:StartPhaseManually(phase)
    if not ns.fight.running then
        ns:WriteOutput('Phase ' .. phase .. ' can only be started during an encounter')
        return
    end
    ns:StartPhase(phase)
end

--Runs twice a second during a fight and shows the reminders that are due
function ns:UpdateFight()
    local now = GetTime()
    ns:ShowDueReminders(ns.plan.main, now - ns.fight.start)
    if ns.fight.phase then
        ns:ShowDueReminders(ns.plan[ns.fight.phase], now - ns.fight.phaseStart)
    end
    ns:ShowDueAbilityReminders(now)
end

--Shows the reminders of a list that are due 'elapsed' seconds after the list's start
function ns:ShowDueReminders(reminders, elapsed)
    for _, reminder in ipairs(reminders or {}) do
        if not reminder.shown then
            ns:CountDown(reminder, reminder.at - elapsed)
        end
        if not reminder.shown and ns:IsDue(reminder, reminder.at - elapsed) then
            ns:Remind(reminder, reminder.at - elapsed)
        end
    end
end

--The numbers a spoken countdown to the press of a ramp or spell says: from the start set on the General page down to 1.
--A number is left out when another step of it is spoken then, from just before that step until its words are said.
--A step with a countdown on its icon, like a spell's 'Soon', isn't spoken with the countdown on, so it doesn't count
function ns:CountdownNumbers(steps)
    local numbers = {}
    for number = math.floor(ns.db.options.countdownFrom or 5), 1, -1 do
        local clash = false
        for _, step in ipairs(steps) do
            local offset = step.offset or 0
            if not step.chargesOf and not step.countdown and offset > 0 and number > offset - 1.25 and number < offset + 0.75 then
                clash = true
            end
        end
        if not clash then
            table.insert(numbers, number)
        end
    end
    return numbers
end

--With the spoken countdown on, says the last seconds before a press, once it is close enough. Returns true when it was
--started
function ns:CountDown(reminder, timeLeft)
    local options = ns.db.options
    --Speech comes a moment after it is asked for, so the numbers are said a little early (a General page setting)
    local lead = options.countdownLead or 0.5
    local numbers = reminder.countNumbers or {}
    local first = numbers[1]
    if not options.spokenCountdown or not reminder.press or reminder.counted or not first or timeLeft > first + 0.6 + lead then
        return false
    end
    reminder.counted = true
    if ns:IsOnCooldownForReminder(reminder, timeLeft) then
        return true
    end
    for _, number in ipairs(numbers) do
        local delay = timeLeft - number - lead
        if delay > -0.3 then
            C_Timer.NewTimer(math.max(0, delay), function()
                if ns.fight.running then
                    ns:SendTts(tostring(number), true)
                end
            end)
        end
    end
    return true
end

--The presses coming up in the fight, soonest first: { reminder, timeLeft }, at most limit of them within window seconds
function ns:GetUpcoming(limit, window)
    if not ns.fight.running then
        return {}
    end
    local now = GetTime()
    local candidates = ns:UpcomingAbilityReminders(now)
    for _, reminder in ipairs(ns.plan.main or {}) do
        if not reminder.shown then
            table.insert(candidates, { reminder = reminder, timeLeft = reminder.at - (now - ns.fight.start) })
        end
    end
    if ns.fight.phase then
        for _, reminder in ipairs(ns.plan[ns.fight.phase] or {}) do
            if not reminder.shown then
                table.insert(candidates, { reminder = reminder, timeLeft = reminder.at - (now - ns.fight.phaseStart) })
            end
        end
    end
    local upcoming = {}
    for _, candidate in ipairs(candidates) do
        if candidate.reminder.press and candidate.timeLeft > -0.25 and candidate.timeLeft <= window then
            table.insert(upcoming, candidate)
        end
    end
    table.sort(upcoming, function(a, b) return a.timeLeft < b.timeLeft end)
    while #upcoming > limit do
        table.remove(upcoming)
    end
    return upcoming
end

--A reminder is due when its time comes. One tied to a spell's charges shows earlier, once the charges need all the
--time that is left to come back
function ns:IsDue(reminder, timeLeft)
    if reminder.chargesOf then
        return timeLeft >= 0 and ns:TimeUntilFullCharges(reminder.chargesOf) >= timeLeft
    end
    return timeLeft <= 0.25
end

--How long it takes to get all charges of a spell back after spending one now. A charges step shows once that is all the
--time left, so a charge spent from then on wouldn't be back for the ramp. When the charges are secret during the
--encounter, the values read before it are used and all charges are assumed spent, so the step shows early rather than late
function ns:TimeUntilFullCharges(spellId)
    local charges = C_Spell.GetSpellCharges(spellId)
    if not charges or ns:IsSecret(charges.currentCharges) or ns:IsSecret(charges.cooldownStartTime) or ns:IsSecret(charges.cooldownDuration) then
        return ns:GetMaxCharges(spellId) * ns:GetRechargeTime(spellId)
    end
    ns:RememberCharges(spellId, charges)
    local maxCharges = ns:GetMaxCharges(spellId)
    if charges.currentCharges >= maxCharges then
        return charges.cooldownDuration
    end
    local rechargeLeft = charges.cooldownStartTime + charges.cooldownDuration - GetTime()
    return rechargeLeft + (maxCharges - charges.currentCharges) * charges.cooldownDuration
end
