local _, ns = ...

--Where the player is: the raid they are in and the boss they are most likely about to pull, for opening the planner on
--that boss and for the ready check summary

--The creature id of a unit, nil when it has none or it can't be read
local function NpcId(unit)
    local guid = UnitGUID(unit)
    if not guid or ns:IsSecret(guid) then
        return nil
    end
    local kind, _, _, _, _, npc = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then
        return nil
    end
    return tonumber(npc)
end

--The raid of Config/Bosses.lua the player is in, with the difficulty id the plans use, or nil outside those raids
function ns:CurrentRaid()
    local _, instanceType, difficultyId, _, _, _, _, instanceId = GetInstanceInfo()
    if instanceType ~= "raid" then
        return nil
    end
    for _, raid in ipairs(ns.raids) do
        if raid.instanceId == instanceId then
            return raid, ns.difficultyAliases[difficultyId] or difficultyId
        end
    end
end

--Bosses of this lockout that are dead, by their localized name
local function KilledBosses()
    local killed = {}
    local _, _, total = GetInstanceLockTimeRemaining()
    for index = 1, total or 0 do
        local name, _, isKilled = GetInstanceLockTimeRemainingEncounter(index)
        if name and isKilled then
            killed[name] = true
        end
    end
    return killed
end

local function LocalizedName(boss)
    if EJ_GetEncounterInfo and boss.journalId then
        local name = EJ_GetEncounterInfo(boss.journalId)
        if name then
            return name
        end
    end
    return boss.name
end

--The boss the player is about to pull and the difficulty: the boss they target, else the first one of the raid not dead
--this lockout. Nil outside the raids of Config/Bosses.lua
function ns:CurrentBoss()
    local raid, difficultyId = ns:CurrentRaid()
    if not raid then
        return nil
    end
    for _, unit in ipairs({ "target", "boss1" }) do
        local npc = NpcId(unit)
        for _, boss in ipairs(npc and raid.bosses or {}) do
            for _, id in ipairs(boss.npcs or {}) do
                if id == npc then
                    return boss.encounterId, difficultyId
                end
            end
        end
    end
    local killed = KilledBosses()
    for _, boss in ipairs(raid.bosses) do
        if not killed[LocalizedName(boss)] then
            return boss.encounterId, difficultyId
        end
    end
    return raid.bosses[#raid.bosses].encounterId, difficultyId
end
