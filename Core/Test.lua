local _, ns = ...

--Testing a plan out of a raid. During real pulls the stages and bars BigWigs or DBM send are recorded, and a test
--replays the recorded pull of a boss with the current plan, so its reminders show as they would on that pull. Without a
--recorded pull, a test shows the reminders of one cast of one ability

local MAX_EVENTS = 3000
local MIN_DURATION = 20

--The pull being recorded: { encounterId, diffSlug, events }. Events are { at = seconds after the pull, kind, ... }
local recording

local function Round(value)
    return math.floor(value * 10 + 0.5) / 10
end

function ns:StartRecording(encounterId, diffSlug)
    recording = { encounterId = encounterId, diffSlug = diffSlug, events = {} }
end

--Keeps a boss mod event of a real pull. kind is 'bar' (source, key, text, duration, spellId, count), 'update' (source,
--key, duration), 'stop' (source, key) or 'stage' (stage)
function ns:RecordBossModEvent(event)
    if not recording or not ns.fight.running or ns.fight.test or #recording.events >= MAX_EVENTS then
        return
    end
    event.at = Round(GetTime() - ns.fight.start)
    if event.duration then
        event.duration = Round(event.duration)
    end
    table.insert(recording.events, event)
end

--Saves the pull that ended. A boss keeps its longest recorded pull per difficulty, it reaches the most of the fight
function ns:StopRecording()
    if not recording or not ns.fight.running or ns.fight.test then
        recording = nil
        return
    end
    local duration = Round(GetTime() - ns.fight.start)
    local bosses = ns.db.recordings
    bosses[recording.encounterId] = bosses[recording.encounterId] or {}
    local previous = bosses[recording.encounterId][recording.diffSlug]
    if duration >= MIN_DURATION and #recording.events > 0 and (not previous or duration >= previous.duration) then
        bosses[recording.encounterId][recording.diffSlug] = {
            duration = duration,
            date = date("%Y-%m-%d"),
            events = recording.events
        }
    end
    recording = nil
end

function ns:GetRecording(encounterId, diffSlug)
    local boss = ns.db.recordings[encounterId]
    return boss and boss[diffSlug]
end

local function Replay(event)
    if event.kind == 'bar' then
        ns:OnBossModBar(event.source, event.key, event.text, event.duration, event.spellId, event.count)
    elseif event.kind == 'update' then
        ns:OnBossModBarUpdate(event.source, event.key, event.duration)
    elseif event.kind == 'stop' then
        ns:OnBossModBarStop(event.source, event.key)
    elseif event.kind == 'stage' then
        ns:StartPhaseFromBossMod(event.stage)
    end
end

local function After(seconds, callback)
    local timer = C_Timer.NewTimer(seconds, callback)
    table.insert(ns.fight.test.timers, timer)
end

--Starts a test of a boss plan. Without 'cast' it replays the recorded pull, with the plan's times and ability lines.
--With cast = { ability, count, seconds } only the ability lines of that ability run, for one cast in that many seconds
function ns:StartTest(specKey, diffSlug, encounterId, cast)
    if ns.fight.running and not ns.fight.test then
        ns:WriteOutput("Tests can't run during a boss fight")
        return false
    end
    local record = not cast and ns:GetRecording(encounterId, diffSlug)
    if not cast and not record then
        return false
    end
    ns:BuildFightPlan(specKey, ns:GetPlan(specKey, diffSlug, encounterId), false, encounterId)
    ns:ResetAbilityTimings()
    ns:StartFight(specKey, nil)
    ns.fight.test = { encounterId = encounterId, diffSlug = diffSlug, timers = {} }
    local duration
    if cast then
        ns.plan = {}
        local ability = cast.ability
        local name = ability.name or (C_Spell.GetSpellInfo(ability.spellId) or {}).name or tostring(ability.spellId)
        ns:OnBossModBar('test', 'test', name .. ' (' .. cast.count .. ')', cast.seconds, ability.spellId, cast.count)
        ns.fight.test.ability = name
        duration = cast.seconds + 3
    else
        for _, event in ipairs(record.events) do
            After(event.at, function() Replay(event) end)
        end
        duration = record.duration + 3
    end
    ns.fight.test.duration = duration
    After(duration, function() ns:StopTest() end)
    ns:OnTestChanged()
    return true
end

function ns:StopTest()
    if ns.fight.test then
        ns:StopFight()
    end
end

function ns:IsTesting()
    return ns.fight.running and ns.fight.test ~= nil
end

--Called when a test starts or stops, the window shows it
function ns:OnTestChanged()
    if ns.RefreshTestStatus then
        ns:RefreshTestStatus()
    end
end
