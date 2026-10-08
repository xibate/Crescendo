local _, ns = ...

local VERSION = "1.0.0"

local INVALID_TIMINGS = "Every line has to be a time, a phase time or a boss ability, like this:\n\n01:25\n00:50, p2\n@Spectral Coils #2\n\n" ..
    "If your text has parts like {time:00:25} it is an MRT note, import it from the Import/Export tab instead."

local GROUPS = {
    { key = 'ramps', tab = 'Ramps', testTab = 'Ramps', header = 'Ramps', toggleOrder = 2, desc = "the timings you will execute this ramp on" },
    { key = 'cooldowns', tab = 'Cooldowns', testTab = 'Cooldowns', header = 'Cooldowns', toggleOrder = 11, desc = "the timings you will use this cooldown on" },
    { key = 'utilities', tab = 'Utility', testTab = 'Utilities', header = 'Utility Spells', toggleOrder = 21, desc = "the timings you will use this spell on" }
}

--An option in ns.db.options. Changing a display option redraws the displays
local function Option(widget, key, redraw)
    widget.width = widget.width or 1
    widget.get = function()
        return ns.db.options[key]
    end
    widget.set = function(_, value)
        ns.db.options[key] = value
        if redraw then
            ns:ResetDisplay()
        end
    end
    return widget
end

--A timings box for one ramp or spell. 'timings' returns the table the text is saved in
local function TimingsBox(name, timings, desc)
    return {
        type = "input",
        multiline = 5,
        name = name,
        desc = desc,
        width = "normal",
        get = function()
            return timings()[name]
        end,
        set = function(_, value)
            timings()[name] = value
        end,
        validate = desc and function(_, value)
            return ns:IsValidTimingsText(value) or INVALID_TIMINGS
        end or nil
    }
end

local function SortedNames(names)
    table.sort(names)
    return names
end

--Names of the ramps, cooldowns and utilities of a spec, sorted, by group key
local function SpecEntries(specName)
    local data = ns.specData[specName]
    local entries = { ramps = {}, cooldowns = {}, utilities = {} }
    for name in pairs(ns:GetRampSteps(specName)) do
        table.insert(entries.ramps, name)
    end
    for _, group in ipairs({ 'cooldowns', 'utilities' }) do
        for _, name in pairs(data[group]) do
            table.insert(entries[group], name)
        end
    end
    for _, names in pairs(entries) do
        SortedNames(names)
    end
    return entries
end

--Description of the steps of each ramp of a spec
local function RampStepsText(specName)
    local lines = {}
    local rampSteps = ns:GetRampSteps(specName)
    for _, name in ipairs(SpecEntries(specName).ramps) do
        table.insert(lines, '|cffffd100' .. name .. '|r')
        for _, step in ipairs(rampSteps[name]) do
            if step.chargesOf then
                table.insert(lines, "- '" .. step.text .. "' on a dynamic time depending on charges")
            else
                table.insert(lines, "- '" .. step.text .. "' " .. step.offset .. " seconds before the timer")
            end
        end
        table.insert(lines, '')
    end
    return table.concat(lines, '\n')
end

local function DropdownValues(source, field)
    return function()
        local values = {}
        for id, entry in pairs(source) do
            values[id] = entry[field]
        end
        return values
    end
end

--Timings boxes of every ramp, cooldown and utility of a spec for one boss and difficulty
local function BossGroup(specName, entries, diffSlug, encounterId, boss)
    local group = {
        type = "group",
        name = boss.name,
        childGroups = "tab",
        order = encounterId,
        args = {
            abilities = {
                type = "group",
                name = "Boss Abilities",
                order = 4,
                args = {
                    desc = {
                        type = "description",
                        fontSize = "medium",
                        name = function()
                            return ns:GetAbilityHelpText(encounterId)
                        end
                    }
                }
            }
        }
    }
    local function timings()
        return ns:GetBossTimings(specName, diffSlug, encounterId)
    end
    for index, info in ipairs(GROUPS) do
        local args = {}
        for _, name in ipairs(entries[info.key]) do
            args[name] = TimingsBox(name, timings, "Input " .. info.desc .. ", in the mm:ss format, each time in a new line")
        end
        group.args[info.key] = { type = "group", name = info.tab, order = index, args = args }
    end
    return group
end

local function ImportExportGroup(specName)
    return {
        type = "group",
        name = "Import/Export",
        order = 3,
        args = {
            header = { type = "header", name = "MRT Note import and export", order = 0 },
            fight = {
                type = "select",
                name = "Fight",
                order = 1,
                width = 1,
                values = DropdownValues(ns.bosses, 'name'),
                get = function() return ns.db.import.fight end,
                set = function(_, fightId) ns.db.import.fight = fightId end
            },
            difficulty = {
                type = "select",
                name = "Difficulty",
                order = 2,
                width = 1,
                values = DropdownValues(ns.difficulties, 'name'),
                get = function() return ns.db.import.difficulty end,
                set = function(_, diffId) ns.db.import.difficulty = diffId end
            },
            text = {
                type = "input",
                name = "Import Text",
                order = 4,
                multiline = 15,
                width = "full",
                get = function() return ns.db.import.importText end,
                set = function(_, value) ns.db.import.importText = value end,
                validate = function(_, value)
                    if value:find(UnitName("player"), 1, true) then
                        return true
                    end
                    return "The imported text doesn't contain the name of your current character, no timings would be imported. Make sure you are " ..
                        "importing an MRT Note that has correctly formatted assignments that match your in-game name."
                end
            },
            import = {
                type = "execute",
                name = "Import Timers",
                order = 5,
                width = 1,
                func = function() ns:ImportNote(specName) end
            },
            export = {
                type = "execute",
                name = "Export Timers",
                order = 6,
                width = 1,
                func = function() ns:ExportNote(specName) end
            }
        }
    }
end

--The timings, test timers and spell toggles of one spec
local function SpecOptions(specName)
    local entries = SpecEntries(specName)
    local timings = {
        type = "group",
        name = specName,
        childGroups = "tree",
        args = {
            fights = { type = "group", name = "Fights", order = 1, childGroups = "tree", args = {} },
            ramps = {
                type = "group",
                name = "Ramp Types",
                order = 2,
                args = {
                    desc = { type = "description", fontSize = "medium", name = RampStepsText(specName) }
                }
            },
            importExport = ImportExportGroup(specName)
        }
    }
    for diffId, difficulty in pairs(ns.difficulties) do
        local bosses = {}
        for encounterId, boss in pairs(ns.bosses) do
            bosses[tostring(encounterId)] = BossGroup(specName, entries, difficulty.slug, encounterId, boss)
        end
        --Higher difficulty ids show up first, so mythic shows before heroic
        timings.args.fights.args[difficulty.slug] = { type = "group", name = difficulty.name, order = 100 - diffId, childGroups = "select", args = bosses }
    end

    local tests = { type = "group", name = specName .. ' Test Timers', childGroups = 'tab', args = {} }
    local toggles = { type = "group", name = specName, args = {} }
    local function testTimings()
        return ns:GetTestTimings(specName)
    end
    for index, info in ipairs(GROUPS) do
        local testArgs = {}
        toggles.args[info.key] = { type = "header", name = info.header, order = info.toggleOrder - 1 }
        for position, name in ipairs(entries[info.key]) do
            testArgs[name] = TimingsBox(name, testTimings)
            toggles.args[info.key .. name] = {
                type = "toggle",
                name = name,
                order = info.toggleOrder + position - 1,
                get = function() return ns:IsEnabled(specName, name) end,
                set = function(_, enabled) ns:SetEnabled(specName, name, enabled) end
            }
        end
        tests.args[info.key] = { type = "group", name = info.testTab, order = index, args = testArgs }
    end
    return timings, tests, toggles
end

local function GeneralOptions()
    return {
        type = "group",
        name = "General Options",
        order = 1,
        args = {
            toggleDisplay = { type = "execute", name = "Toggle Display", width = 1, order = 1, func = function() ns:ToggleDisplay() end },
            resetDefaults = {
                type = "execute",
                name = "Reset Default Settings",
                width = 1,
                order = 2,
                func = function()
                    ns:ResetOptions()
                    ns:ResetDisplay()
                end
            },
            positionHeader = { type = "header", name = "Position", order = 10 },
            framePositionX = Option({ type = "range", name = "Display X Position", softMin = -1000, softMax = 1000, order = 11, step = 1, bigStep = 10 }, 'framePositionX', true),
            framePositionY = Option({ type = "range", name = "Display Y Position", softMin = -1000, softMax = 1000, order = 12, step = 1, bigStep = 10 }, 'framePositionY', true),
            growDirection = Option({ type = "select", name = "Grow Direction", order = 13, values = { top = 'top', bottom = 'bottom', left = 'left', right = 'right' } }, 'growDirection', true),
            sizeHeader = { type = "header", name = "Size", order = 20 },
            textSize = Option({ type = "range", name = "Main Text Size", min = 0.5, max = 5, order = 21, step = 0.1, bigStep = 0.1 }, 'textSize', true),
            timerSize = Option({ type = "range", name = "Timer Text Size", min = 0.5, max = 5, order = 22, step = 0.1, bigStep = 0.1 }, 'timerSize', true),
            iconSizeW = Option({ type = "range", name = "Icon Width", min = 10, max = 200, order = 23, step = 1, bigStep = 2 }, 'iconSizeW', true),
            iconSizeH = Option({ type = "range", name = "Icon Height", min = 10, max = 200, order = 23, step = 1, bigStep = 2 }, 'iconSizeH', true),
            displaySpacing = Option({ type = "range", name = "Display Spacing", min = 0, softMin = 40, max = 500, softMax = 300, order = 24, step = 1, bigStep = 5 }, 'displaySpacing', true),
            ttsHeader = { type = "header", name = "Text to Speech", order = 30 },
            ttsPlay = {
                type = "execute",
                name = "Play Voice",
                desc = "Plays a message to test the TTS. This won't work if TTS is disabled",
                width = 1,
                order = 31,
                func = function() ns:SendTts('Zynx Ramp Helper') end
            },
            ttsEnabled = Option({ type = "toggle", name = "Enable Text to Speech", order = 32 }, 'ttsEnabled'),
            ttsVoice = Option({
                type = "select",
                name = "Voice",
                order = 33,
                values = function()
                    local voices = {}
                    for _, voice in pairs(C_VoiceChat.GetTtsVoices()) do
                        voices[voice.voiceID] = voice.name
                    end
                    return voices
                end
            }, 'ttsVoice'),
            ttsRate = Option({ type = "range", name = "Rate", min = -10, max = 10, order = 34, step = 1, bigStep = 0.5 }, 'ttsRate'),
            ttsVolume = Option({ type = "range", name = "Volume", min = 0, max = 100, order = 35, step = 1, bigStep = 5 }, 'ttsVolume'),
            mrtHeader = { type = "header", name = "Using MRT Note", order = 40 },
            mrtDescription = {
                type = "description",
                name = "When one or both of the options below are enabled, the times in the addon are ignored and the times in the selected MRT notes " ..
                    "are used instead. Boss ability lines (@...) in the addon still apply.",
                order = 41
            },
            readFromNote = Option({ type = "toggle", name = "Read From Main MRT Note", desc = "Load assignments from the main MRT Note.", order = 42 }, 'readFromNote'),
            mrtPersonalNote = Option({ type = "toggle", name = "Read From Personal MRT Note", desc = "Load assignments from the personal MRT Note.", order = 43 }, 'mrtPersonalNote'),
            extraHeader = { type = "header", name = "Extra Options", order = 50 },
            preReqsOnly = Option({
                type = "toggle",
                name = "Only Prerequisites Mode",
                desc = "All the setup steps for a ramp are considered prerequisites, while the final cooldown button press is not. In this mode you will " ..
                    "still be shown all the setup steps, but not the final warning to consume the ramp. In case you have another addon or weakaura that warns you of that.",
                order = 51
            }, 'preReqsOnly'),
            timerDuration = Option({ type = "range", name = "Timer Duration", min = 2, max = 10, order = 52, step = 1 }, 'timerDuration')
        }
    }
end

local ABOUT = "Zynx Ramp Helper reminds healers of every step of their raid ramps. Instead of setting up each part of a ramp as a separate " ..
    "warning, you enter when a ramp should land and the addon reminds you of all the steps leading up to it.\n\n" ..
    "The Timings tab has a page per spec with every boss on each difficulty. Type the times of each ramp or cooldown in the 'mm:ss' or 'ss' " ..
    "format, one per line, and the reminders for them show when that boss is pulled. Ramp Types shows the steps of each ramp of a spec.\n\n" ..
    "Phases follow BigWigs or DBM: a time written as '00:50, p2' counts from when your boss mod shows stage 2 (intermissions are stages " ..
    "like p1.5). Without a boss mod you can start a phase yourself with '/zrh phase 2' from a macro.\n\n" ..
    "A line can also follow a boss ability instead of a time, like '@Spectral Coils #2' for the second cast. The Boss Abilities tab of each " ..
    "boss explains how and lists the abilities your boss mod showed on that boss.\n\n" ..
    "The Options tab changes the size, position and voice of the reminders, and can read your times from MRT notes instead. To try the " ..
    "reminders on a target dummy, turn on Testing Mode in the Testing tab.\n\n" ..
    "Version " .. VERSION

local function BuildOptionsTable()
    local options = {
        type = "group",
        childGroups = "tab",
        args = {
            timings = { type = "group", name = "Timings", childGroups = "select", order = 1, args = {} },
            options = {
                type = "group",
                name = "Options",
                childGroups = "tab",
                order = 2,
                args = {
                    generalOptions = GeneralOptions(),
                    specOptions = { type = "group", name = "Spec Options", childGroups = "select", order = 2, args = {} }
                }
            },
            testing = {
                type = "group",
                name = "Testing",
                childGroups = 'select',
                order = 3,
                args = {
                    testModeDescription = {
                        type = "description",
                        name = "When testing mode is enabled, starting combat with any entity will run the test timers for your current spec",
                        fontSize = "medium",
                        order = 1
                    },
                    testMode = {
                        type = "toggle",
                        name = "Enable Testing Mode",
                        order = 2,
                        get = function() return ns.db.testing.testMode end,
                        set = function(_, enabled) ns.db.testing.testMode = enabled end
                    }
                }
            },
            about = {
                type = "group",
                name = "About",
                order = 4,
                args = {
                    desc = { type = "description", name = ABOUT, order = 1, fontSize = "medium" }
                }
            }
        }
    }
    for _, specName in pairs(ns.specs) do
        local timings, tests, toggles = SpecOptions(specName)
        options.args.timings.args[specName] = timings
        options.args.testing.args[specName] = tests
        options.args.options.args.specOptions.args[specName] = toggles
    end
    return options
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= "ZynxRampHelper" then
        return
    end
    ns:InitDatabase()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Zynx Ramp Helper", BuildOptionsTable())
    local optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Zynx Ramp Helper", "Zynx Ramp Helper")
    SLASH_ZYNXRAMPHELPER1 = "/zrh"
    SlashCmdList.ZYNXRAMPHELPER = function(message)
        local phase = message:match("^%s*phase%s+(%d+%.?%d*)")
        if phase then
            ns:StartPhaseManually(phase)
        else
            Settings.OpenToCategory(optionsFrame.name)
        end
    end
end)
