--Namespace
local _, ns = ...
local version = "1.0.0"
local defaultOptions = {
    ['testing'] = {
        ['testMode'] = false
    },
    ['options'] = {
        ['toggleDisplay'] = false,
        ['framePositionX'] = 0,
        ['framePositionY'] = 200,
        ['growDirection'] = 'top',
        ['textSize'] = 2,
        ['timerSize'] = 2.5,
        ['iconSizeW'] = 48,
        ['iconSizeH'] = 48,
        ['displaySpacing'] = 70,
        ['ttsEnabled'] = true,
        ['ttsVoice'] = 1,
        ['ttsRate'] = -1,
        ['ttsVolume'] = 100,
        ['preReqsOnly'] = false,
        ['readFromNote'] = false,
        ['mrtPersonalNote'] = false,
        ['timerDuration'] = 3,
        ['specs'] = {}
    },
    ['import'] = {
        ['fight'] = nil,
        ['difficulty'] = nil,
        ['importText'] = nil
    },
    --Boss abilities BigWigs or DBM showed bars for, per encounter id
    ['seenAbilities'] = {}
}

local addonLoader = CreateFrame("Frame")
addonLoader:RegisterEvent("ADDON_LOADED")
addonLoader:RegisterEvent("PLAYER_LOGOUT")
addonLoader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == "ZynxRampHelper" then
        if type(ZynxRampHelperDB) ~= 'table' then
            ZynxRampHelperDB = defaultOptions
        else
            for key, optionGroup in pairs(defaultOptions) do
                if not ZynxRampHelperDB[key] then
                    ZynxRampHelperDB[key] = {}
                end
                for option, value in pairs(optionGroup) do
                    if not ZynxRampHelperDB[key][option] then
                        ZynxRampHelperDB[key][option] = value
                    end
                end
            end
        end
        --Initialize configurations
        ZynxRampHelperDB.options.toggleDisplay = false
        ZynxRampHelperDB.import.fight = nil
        ZynxRampHelperDB.import.difficulty = nil
        ZynxRampHelperDB.import.importText = nil
        local defaultOptionWidth = 1

        --Initialize options table
        local optionsTable = {
            type = "group",
            childGroups = "tab",
            args = {
                timings = {
                    type = "group",
                    name = "Timings",
                    childGroups = "select",
                    order = 1,
                    args = {}
                },
                options = {
                    type = "group",
                    name = "Options",
                    childGroups = "tab",
                    order = 2,
                    args = {
                        generalOptions = {
                            type = "group",
                            name = "General Options",
                            order = 1,
                            args = {
                                toggleDisplay = {
                                    type = "execute",
                                    name = "Toggle Display",
                                    width = defaultOptionWidth,
                                    order = 1,
                                    func = function()
                                        ns:ToggleDisplay()
                                    end
                                },
                                resetDefaults = {
                                    type = "execute",
                                    name = "Reset Default Settings",
                                    width = defaultOptionWidth,
                                    order = 2,
                                    func = function()
                                        for option, defaultValue in pairs(defaultOptions.options) do
                                            ZynxRampHelperDB.options[option] = defaultValue
                                        end
                                        ns:ResetDisplay()
                                    end
                                },
                                positionHeader = {
                                    type = "header",
                                    name = "Position",
                                    order = 10
                                },
                                framePositionX = {
                                    type = "range",
                                    name = "Display X Position",
                                    width = defaultOptionWidth,
                                    softMin = -1000,
                                    softMax = 1000,
                                    order = 11,
                                    step = 1,
                                    bigStep = 10,
                                    get = function() return ZynxRampHelperDB.options.framePositionX end,
                                    set = function(_, valueX)
                                        ZynxRampHelperDB.options.framePositionX = valueX
                                        ns:ResetDisplay()
                                    end
                                },
                                framePositionY = {
                                    type = "range",
                                    name = "Display Y Position",
                                    width = defaultOptionWidth,
                                    softMin = -1000,
                                    softMax = 1000,
                                    order = 12,
                                    step = 1,
                                    bigStep = 10,
                                    get = function() return ZynxRampHelperDB.options.framePositionY end,
                                    set = function(_, valueY)
                                        ZynxRampHelperDB.options.framePositionY = valueY
                                        ns:ResetDisplay()
                                    end
                                },
                                displayGrowDirection = {
                                    type = "select",
                                    name = "Grow Direction",
                                    width = defaultOptionWidth,
                                    order = 13,
                                    values = {['top'] = 'top', ['bottom'] = 'bottom', ['left'] = 'left', ['right'] = 'right'},
                                    get = function() return ZynxRampHelperDB.options.growDirection end,
                                    set = function(_, direction)
                                        ZynxRampHelperDB.options.growDirection = direction
                                        ns:ResetDisplay()
                                    end
                                },
                                sizeHeader = {
                                    type = "header",
                                    name = "Size",
                                    order = 20
                                },
                                textSize = {
                                    type = "range",
                                    name = "Main Text Size",
                                    width = defaultOptionWidth,
                                    min = 0.5,
                                    softMin = 0.5,
                                    max = 5,
                                    softMax = 5,
                                    order = 21,
                                    step = 0.1,
                                    bigStep = 0.1,
                                    get = function() return ZynxRampHelperDB.options.textSize end,
                                    set = function(_, size)
                                        ZynxRampHelperDB.options.textSize = size
                                        ns:ResetDisplay()
                                    end
                                },
                                timerSize = {
                                    type = "range",
                                    name = "Timer Text Size",
                                    width = defaultOptionWidth,
                                    min = 0.5,
                                    softMin = 0.5,
                                    max = 5,
                                    softMax = 5,
                                    order = 22,
                                    step = 0.1,
                                    bigStep = 0.1,
                                    get = function() return ZynxRampHelperDB.options.timerSize end,
                                    set = function(_, size)
                                        ZynxRampHelperDB.options.timerSize = size
                                        ns:ResetDisplay()
                                    end
                                },
                                iconSizeW = {
                                    type = "range",
                                    name = "Icon Width",
                                    width = defaultOptionWidth,
                                    min = 10,
                                    softMin = 10,
                                    max = 200,
                                    softMax = 200,
                                    order = 23,
                                    step = 1,
                                    bigStep = 2,
                                    get = function() return ZynxRampHelperDB.options.iconSizeW end,
                                    set = function(_, size)
                                        ZynxRampHelperDB.options.iconSizeW = size
                                        ns:ResetDisplay()
                                    end
                                },
                                iconSizeH = {
                                    type = "range",
                                    name = "Icon Height",
                                    width = defaultOptionWidth,
                                    min = 10,
                                    softMin = 10,
                                    max = 200,
                                    softMax = 200,
                                    order = 23,
                                    step = 1,
                                    bigStep = 2,
                                    get = function() return ZynxRampHelperDB.options.iconSizeH end,
                                    set = function(_, size)
                                        ZynxRampHelperDB.options.iconSizeH = size
                                        ns:ResetDisplay()
                                    end
                                },
                                displaySpacing = {
                                    type = "range",
                                    name = "Display Spacing",
                                    width = defaultOptionWidth,
                                    min = 0,
                                    softMin = 40,
                                    max = 500,
                                    softMax = 300,
                                    order = 24,
                                    step = 1,
                                    bigStep = 5,
                                    get = function() return ZynxRampHelperDB.options.displaySpacing end,
                                    set = function(_, spacing)
                                        ZynxRampHelperDB.options.displaySpacing = spacing
                                        ns:ResetDisplay()
                                    end
                                },
                                ttsHeader = {
                                    type = "header",
                                    name = "Text to Speech",
                                    order = 30
                                },
                                ttsPlay = {
                                    type = "execute",
                                    name = "Play Voice",
                                    desc = "Plays a message to test the TTS. This won't work if TTS is disabled",
                                    width = defaultOptionWidth,
                                    order = 31,
                                    func = function()
                                        ns:SendTts('Zynx Ramp Helper')
                                    end
                                },
                                ttsEnabled = {
                                    type = "toggle",
                                    name = "Enable Text to Speech",
                                    width = defaultOptionWidth,
                                    order = 32,
                                    get = function() return ZynxRampHelperDB.options.ttsEnabled end,
                                    set = function(_, value) ZynxRampHelperDB.options.ttsEnabled = value end
                                },
                                ttsVoice = {
                                    type = "select",
                                    name = "Voice",
                                    width = defaultOptionWidth,
                                    order = 33,
                                    values = function()
                                        local voices = {}
                                        for _, voice in pairs(C_VoiceChat.GetTtsVoices()) do
                                            voices[voice.voiceID] = voice.name
                                        end
                                        return voices
                                    end,
                                    get = function() return ZynxRampHelperDB.options.ttsVoice end,
                                    set = function(_, voice) ZynxRampHelperDB.options.ttsVoice = voice end
                                },
                                ttsRate = {
                                    type = "range",
                                    name = "Rate",
                                    width = defaultOptionWidth,
                                    min = -10,
                                    softMin = -10,
                                    max = 10,
                                    softMax = 10,
                                    order = 34,
                                    step = 1,
                                    bigStep = 0.5,
                                    get = function() return ZynxRampHelperDB.options.ttsRate end,
                                    set = function(_, rate) ZynxRampHelperDB.options.ttsRate = rate end
                                },
                                ttsVolume = {
                                    type = "range",
                                    name = "Volume",
                                    width = defaultOptionWidth,
                                    min = 0,
                                    softMin = 0,
                                    max = 100,
                                    softMax = 100,
                                    order = 35,
                                    step = 1,
                                    bigStep = 5,
                                    get = function() return ZynxRampHelperDB.options.ttsVolume end,
                                    set = function(_, volume) ZynxRampHelperDB.options.ttsVolume = volume end
                                },
                                mrtHeader = {
                                    type = "header",
                                    name = "Using MRT Note",
                                    order = 40
                                },
                                mrtDescription = {
                                    type = "description",
                                    name = "When one or both of options below is enabled, your manually input or imported timings are ignored, and instead the addon Will grab from the selected MRT option(s).",
                                    order = 41
                                },
                                readFromNote = {
                                    type = "toggle",
                                    name = "Read From Main MRT Note",
                                    desc = "Load assignments from the main MRT Note.",
                                    width = defaultOptionWidth,
                                    order = 42,
                                    get = function() return ZynxRampHelperDB.options.readFromNote end,
                                    set = function(_, value) ZynxRampHelperDB.options.readFromNote = value end
                                },
                                mrtPersonalNote = {
                                    type = "toggle",
                                    name = "Read From Personal MRT Note",
                                    desc = "Load assignments from the personal MRT Note.",
                                    width = defaultOptionWidth,
                                    order = 43,
                                    get = function() return ZynxRampHelperDB.options.mrtPersonalNote end,
                                    set = function(_, value) ZynxRampHelperDB.options.mrtPersonalNote = value end
                                },
                                extraHeader = {
                                    type = "header",
                                    name = "Extra Options",
                                    order = 50
                                },
                                preReqsOnly = {
                                    type = "toggle",
                                    name = "Only Prerequisites Mode",
                                    desc = "All the setup steps for a ramp are considered prerequisites, while the final cooldown button press is not. In this mode you will still be shown all " ..
                                        "the setup steps, but not the final warning to consume the ramp. In case you have another addon or weakaura that warns you of that.",
                                    width = defaultOptionWidth,
                                    order = 51,
                                    get = function() return ZynxRampHelperDB.options.preReqsOnly end,
                                    set = function(_, value) ZynxRampHelperDB.options.preReqsOnly = value end
                                },
                                timerDuration = {
                                    type = "range",
                                    name = "Timer Duration",
                                    width = defaultOptionWidth,
                                    min = 2,
                                    softMin = 2,
                                    max = 10,
                                    softMax = 10,
                                    order = 52,
                                    step = 1,
                                    get = function() return ZynxRampHelperDB.options.timerDuration end,
                                    set = function(_, volume) ZynxRampHelperDB.options.timerDuration = volume end
                                },
                            }
                        },
                        specOptions = {
                            type = "group",
                            name = "Spec Options",
                            childGroups = "select",
                            order = 2,
                            args = {}
                        }
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
                            name = "When testing mode is enabled, starting combat with any entity will run the test timers for you current spec",
                            fontSize = "medium",
                            order = 1
                        },
                        testMode = {
                            type = "toggle",
                            name = "Enable Testing Mode",
                            order = 2,
                            get = function() return ZynxRampHelperDB.testing.testMode end,
                            set = function(_, testingEnabled) ZynxRampHelperDB.testing.testMode = testingEnabled end
                        }
                    }
                },
                about = {
                    type = "group",
                    name = "About",
                    order = 4,
                    args = {
                        aboutDesc = {
                            type = "description",
                            name = "Zynx Ramp Helper is a tool designed to help healers manage their cooldowns in order to properly execute ramps. It works similarly to " ..
                            "assigning every part of a ramp's instructions as warnings or reminders but facilitates this process by automatically creating reminders for all the steps based " ..
                            "on the best recommended practices for the spec. Inside the timings menu you will find all the specs currently supported and different menus for each " ..
                            "boss on each difficulty.\n\nOpening the Ramp Types menu for each spec will show you all the current configured ramps for that spec and what reminders they consist of, " ..
                            "typing a timer in the 'mm:ss' or 'ss' formats in the corresponding window for each ramp on a boss will create all the assignments for that ramp at that time " ..
                            "when that boss is pulled.\n\nTo change the size or style of the reminders head to the Options menu, to test the addon on a dummy head to the Testing menu and " ..
                            "turn on Testing Mode, which will pull from the test timers for your spec when you start combat.\n\nThere are also settings in the options to automatically grab " ..
                            "your assigned timers from your currently active MRT note, if you prefer to do that instead of writing your own timings in the addon " ..
                            "\n\nSince Midnight phases come from BigWigs or DBM: timings written as '00:50, p2' start counting when your boss mod shows stage 2 " ..
                            "(intermissions are stages like p1.5). Without a boss mod you can start a phase yourself with '/zrh phase 2' from a macro." ..
                            "\n\nA timings line can also follow a boss ability instead of a time, like '@Spectral Coils #2' for the second cast. " ..
                            "The Boss Abilities tab of each boss explains how and lists the abilities your boss mod showed on that boss." ..
                            "\n\nZynx Ramp Helper is based on Harrek's Healer Ramp Helper, made by Harrek. The ramps and most of the addon are his work, " ..
                            "this version updates it for Midnight. Please don't send questions about this version to Harrek, the links below are his " ..
                            "community and his original addon." ..
                            "\n\nAddon Version: " .. version .. "\n\n",
                            order = 1,
                            fontSize = "medium"
                        },
                        sbpDiscord = {
                            type = "execute",
                            name = "Spiritbloom.Pro Discord",
                            order = 2,
                            width = 1.5,
                            func = function()
                                local AceGUI = LibStub("AceGUI-3.0")
                                local frame = AceGUI:Create("Window")
                                frame:SetTitle("Spiritbloom.Pro Discord")
                                frame:SetWidth(300)
                                frame:SetHeight(80)
                                frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
                                local textBox = AceGUI:Create("EditBox")
                                textBox:SetFullWidth(true)
                                textBox:SetText("discord.spiritbloom.pro")
                                textBox:HighlightText()
                                textBox:SetFocus()
                                frame:AddChild(textBox)
                            end
                        },
                        evokerDiscord = {
                            type = "execute",
                            name = "Wyrmrest Temple Discord",
                            order = 3,
                            width = 1.5,
                            func = function()
                                local AceGUI = LibStub("AceGUI-3.0")
                                local frame = AceGUI:Create("Window")
                                frame:SetTitle("Wyrmrest Temple Discord")
                                frame:SetWidth(300)
                                frame:SetHeight(80)
                                frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
                                local textBox = AceGUI:Create("EditBox")
                                textBox:SetFullWidth(true)
                                textBox:SetText("https://discord.gg/evoker")
                                textBox:HighlightText()
                                textBox:SetFocus()
                                frame:AddChild(textBox)
                            end
                        },
                        cursePage = {
                            type = "execute",
                            name = "Original Addon by Harrek",
                            order = 4,
                            width = 1.5,
                            func = function()
                                local AceGUI = LibStub("AceGUI-3.0")
                                local frame = AceGUI:Create("Window")
                                frame:SetTitle("Harrek's Healer Ramp Helper")
                                frame:SetWidth(300)
                                frame:SetHeight(80)
                                frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
                                local textBox = AceGUI:Create("EditBox")
                                textBox:SetFullWidth(true)
                                textBox:SetText("https://www.curseforge.com/wow/addons/harreks-healer-ramp-helper")
                                textBox:HighlightText()
                                textBox:SetFocus()
                                frame:AddChild(textBox)
                            end
                        }
                    }
                }
            },
        }

        local currentOrder = 2
        --For each spec in the data file
        for specId, specName in pairs(ns.specs) do
            --Check ZynxRampHelperDB for existence of this spec
            if not ZynxRampHelperDB[specName] then
                ZynxRampHelperDB[specName] = {}
            end
            --Initialize test timers for this spec
            if not ZynxRampHelperDB[specName].testTimers then
                ZynxRampHelperDB[specName].testTimers = {}
            end
            local specTestTimers = {
                type = "group",
                name = specName .. ' Test Timers',
                childGroups = 'tab',
                args = {
                    ramps = {
                        type = "group",
                        name = 'Ramps',
                        args = {}
                    },
                    cooldowns = {
                        type = "group",
                        name = 'Cooldowns',
                        args = {}
                    },
                    utilities = {
                        type = "group",
                        name = 'Utilities',
                        args = {}
                    },
                }
            }
            --Build list of cooldowns for settings options
            local rampsIndex, cooldownsIndex, utilitiesIndex = 2, 11, 21
            if not ZynxRampHelperDB.options.specs[specName] then
                ZynxRampHelperDB.options.specs[specName] = {}
            end
            local specSpells = {
                type = "group",
                name = specName,
                args = {
                    ramps = {
                        type = "header",
                        name = "Ramps",
                        order = 1
                    },
                    cooldowns = {
                        type = "header",
                        name = "Cooldowns",
                        order = 10
                    },
                    utilities = {
                        type = "header",
                        name = "Utility Spells",
                        order = 20
                    }
                }
            }
            --Get the ramp types from the data file of the spec
            local rampTypes = ns[specName]['rampTypes']()
            local cooldowns = ns[specName]['cooldowns']
            local utilities = ns[specName]['utilities'] or {}
            --Initialize string description of the spec's ramps
            local specRampFiles = ""
            local firstType = true
            --For each type of ramp in the data
            for type, assignments in pairs(rampTypes) do
                --Build string description of the ramps
                if firstType then
                    firstType = false
                else
                    specRampFiles = specRampFiles .. '\n\n'
                end
                specRampFiles = specRampFiles .. '|cffffd100' .. type .. '|r\n'
                for _, assignment in pairs(assignments) do
                    specRampFiles = specRampFiles .. "- '" .. assignment['text'] .. "'"
                    if assignment['dynamic'] then
                        specRampFiles = specRampFiles .. ' on a dynamic time depending on charges'
                    else
                        specRampFiles = specRampFiles .. ' ' .. assignment['offset'] .. ' seconds before the timer'
                    end
                    specRampFiles = specRampFiles .. '\n'
                end
            end
            --Local variable to store the data for this spec
            local specTable = {
                type = "group",
                name = specName,
                childGroups = "tree",
                args = {
                    fights = {
                        type = "group",
                        name = "Fights",
                        order = 1,
                        childGroups = "tree",
                        args = {}
                    },
                    ramps = {
                        type = "group",
                        name = "Ramp Types",
                        order = 2,
                        args = {
                            desc = {
                            type = "description",
                            name = specRampFiles,
                            fontSize = "medium"
                        }}
                    },
                    --Import and export functionality
                    importExport = {
                        type = "group",
                        name = "Import/Export",
                        order = 3,
                        args = {
                            importHeader = {
                                type = "header",
                                name = "MRT Note import and export",
                                order = 0
                            },
                            importFight = {
                                type = "select",
                                name = "Fight",
                                order = 1,
                                width = defaultOptionWidth,
                                values = function()
                                    local fights = {}
                                    for fightId, fight in pairs(ns.bosses) do
                                        fights[fightId] = fight.name
                                    end
                                    return fights
                                end,
                                get = function() return ZynxRampHelperDB.import.fight end,
                                set = function(_, fightId) ZynxRampHelperDB.import.fight = fightId end
                            },
                            importDifficulty = {
                                type = "select",
                                name = "Difficulty",
                                order = 2,
                                width = defaultOptionWidth,
                                values = function()
                                    local difficulties = {}
                                    for diffId, diff in pairs(ns.difficulties) do
                                        difficulties[diffId] = diff.name
                                    end
                                    return difficulties
                                end,
                                get = function() return ZynxRampHelperDB.import.difficulty end,
                                set = function(_, diffId) ZynxRampHelperDB.import.difficulty = diffId end
                            },
                            pasteDefault = {
                                type = "execute",
                                name = "Paste Default Assignments For This Boss",
                                order = 3,
                                width = defaultOptionWidth * 2,
                                func = function()
                                    ns:PasteDefaultForSpecificBoss(specName)
                                end
                            },
                            importText = {
                                type = "input",
                                name = "Import Text",
                                order = 4,
                                multiline = 15,
                                width = "full",
                                set = function(_, val) ZynxRampHelperDB.import.importText = val end,
                                get = function() return ZynxRampHelperDB.import.importText end,
                                validate = function(_, val)
                                    local containsToonName = string.find(val, UnitName("player"))
                                    if containsToonName then
                                        return true
                                    else
                                        return "The imported text doesn't contain the name of your current character, no timings would be imported. Make sure you are importing an MRT Note that has " ..
                                        "correctly formatted assignments that match your in-game name."
                                    end
                                end
                            },
                            importButton = {
                                type = "execute",
                                name = "Import Timers",
                                order = 5,
                                width = defaultOptionWidth,
                                func = function()
                                    ns:ImportNote(specName)
                                end
                            },
                            exportButton = {
                                type = "execute",
                                name = "Export Timers",
                                order = 6,
                                width = defaultOptionWidth,
                                func = function()
                                    local fightId = ZynxRampHelperDB.import.fight
                                    local diffId = ZynxRampHelperDB.import.difficulty
                                    if fightId and diffId then
                                        local diffSlug = ns.difficulties[diffId].slug
                                        local timingsString = ns:ConvertTimingsToNote(specName, diffSlug, fightId)
                                        ZynxRampHelperDB.import.importText = timingsString
                                    end
                                end
                            },
                            defaultsHeader = {
                                type = "header",
                                name = "Default Assignments",
                                order = 7
                            },
                            defaultsDescription = {
                                type = "description",
                                name = "The addon comes with some default assignments saved based on recommended timings for each spec, using this option will " ..
                                    "import all the currently configured default assignments for all bosses for this specialization. " ..
                                    "If you want to import them for a single boss instead use the button located below the boss selection dropdowns. " ..
                                    "|cffff680aWarning:|r this will overwrite any assignments currently set up",
                                order = 8,
                                fontSize = "medium"
                            },
                            importAllDefaults = {
                                type = "execute",
                                name = "Import all default Assignments",
                                order = 9,
                                width = defaultOptionWidth * 2,
                                func = function()
                                    local importedBossList = ''
                                    for fightId, fightData in pairs(ns.bosses) do
                                        for diffId, diffData in pairs(ns.difficulties) do
                                            local diffSlug = diffData.slug
                                            local importText = ns:GetDefaultAssignments(specName, fightId, diffSlug)
                                            if importText ~= "" then
                                                importedBossList = importedBossList .. ' - ' .. diffData.name .. ' ' .. fightData.name .. '\n'
                                                local timers = ns:ConvertNoteToTable(importText, specName, fightId, diffSlug)
                                                for type, timings in pairs(ZynxRampHelperDB[specName][diffSlug][tostring(fightId)]) do
                                                    ZynxRampHelperDB[specName][diffSlug][tostring(fightId)][type] = ns:KeepAbilityLines(timings)
                                                end
                                                for spell, timings in pairs(timers) do
                                                    local rampType = ns[specName]['cooldowns'][tonumber(spell)]
                                                    if rampType then
                                                        local timingsString = ''
                                                        for _, time in pairs(timings) do
                                                            timingsString = timingsString .. time .. '\n'
                                                        end
                                                        ZynxRampHelperDB[specName][diffSlug][tostring(fightId)][rampType] = (ZynxRampHelperDB[specName][diffSlug][tostring(fightId)][rampType] or '') .. timingsString
                                                    end
                                                end
                                                ZynxRampHelperDB.import.importText = '';
                                            end
                                        end
                                    end
                                    local resultText = ''
                                    if importedBossList == '' then
                                        resultText = "There are currently no default assignments to import for your spec."
                                    else
                                        resultText = "Successfully imported default assignments for the following bosses:\n" .. importedBossList
                                    end
                                    ns:WriteOutput(resultText)
                                end
                            }
                        }
                    }
                }
            }
            --For each difficulty in the data file
            for diffId, diff in pairs(ns.difficulties) do
                local diffSlug = diff.slug
                local diffName = diff.name
                --Check ZynxRampHelperDB if this difficulty exists for this spec
                if not ZynxRampHelperDB[specName][diffSlug] then
                    ZynxRampHelperDB[specName][diffSlug] = {}
                end
                --Add the difficulty as a group to the specTable
                specTable.args.fights.args[diffSlug] = {
                    type = "group",
                    name = diffName,
                    order = 100 - diffId, --higher diff id shows up first, so mythic shows before heroic
                    childGroups = "select",
                    args = {}
                }
                --For each encounter in the data file
                for encounterId, encounter in pairs(ns.bosses) do
                    --Check ZynxRampHelperDB if this boss exists for this difficulty on this spec
                    if not ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)] then
                        ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)] = {}
                    end
                    --Local variable to store the ramp types
                    local rampTypeOptions = {}
                    --For each type of ramp in the data
                    for type, _ in pairs(rampTypes) do
                        --Check ZynxRampHelperDB if this rampType exists on this boss for this difficulty on this spec
                        if not ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][type] then
                            ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][type] = ""
                        end
                        --Add a multiline text input with the name of that ramp type
                        rampTypeOptions[diffSlug .. '-' .. encounterId ..'-' .. type] = {
                            type = "input",
                            multiline = 5,
                            name = type,
                            desc = "Input the timings you will execute this ramp on, in the mm:ss format, each time in a new line",
                            width = "normal",
                            set = function(_, val) ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][type] = val end,
                            get = function() return ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][type] end,
                            validate = function(_, val)
                                local valid = ns:IsValidTimingsText(val)
                                if valid then
                                    return true
                                else
                                    return "Your input contains an invalid character. Your times are supposed to look like this:\n\n01:25\n00:50, p2\n@Spectral Coils #2\n\nIf your input contains parts like this:\n\n" ..
                                    "{time:00:25,SCC:468794:1}\n\nThen it is in MRT Note format, and you should import it instead."
                                end
                            end
                        }
                        --Add this type of ramp to the test timers
                        if not specTestTimers.args.ramps.args[type] then
                            specTestTimers.args.ramps.args[type] = {
                                type = "input",
                                multiline = 5,
                                order = 1,
                                name = type,
                                width = "normal",
                                set = function(_, val) ZynxRampHelperDB[specName].testTimers[type] = val end,
                                get = function() return ZynxRampHelperDB[specName].testTimers[type] end
                            }
                        end
                        --Add this ramp to the options
                        if not specSpells.args[type] then
                            if not ZynxRampHelperDB.options.specs[specName][type] then
                                ZynxRampHelperDB.options.specs[specName][type] = true
                            end
                            specSpells.args[type] = {
                                type = "toggle",
                                name = type,
                                order = rampsIndex,
                                set = function(_, val) ZynxRampHelperDB.options.specs[specName][type] = val end,
                                get = function() return ZynxRampHelperDB.options.specs[specName][type] end
                            }
                            rampsIndex = rampsIndex + 1
                        end
                    end
                    --Local variable to store cooldowns
                    local cooldownOptions = {}
                    --For each cooldown in the data
                    for _, cooldown in pairs(cooldowns) do
                        --Check ZynxRampHelperDB if this cooldown exists on this boss for this difficulty on this spec
                        if not ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][cooldown] then
                            ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][cooldown] = ""
                        end
                        --Add a multiline text input with the name of that cooldown
                        cooldownOptions[diffSlug .. '-' .. encounterId ..'-' .. cooldown] = {
                            type = "input",
                            multiline = 5,
                            name = cooldown,
                            desc = "Input the timings you will use this cooldown on, in the mm:ss format, each time in a new line",
                            width = "normal",
                            set = function(_, val) ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][cooldown] = val end,
                            get = function() return ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][cooldown] end,
                            validate = function(_, val)
                                local valid = ns:IsValidTimingsText(val)
                                if valid then
                                    return true
                                else
                                    return "Your input contains an invalid character. Your times are supposed to look like this:\n\n01:25\n00:50, p2\n@Spectral Coils #2\n\nIf your input contains parts like this:\n\n" ..
                                    "{time:00:25,SCC:468794:1}\n\nThen it is in MRT Note format, and you should import it instead."
                                end
                            end
                        }
                        --Add this cooldown to the test timers
                        if not specTestTimers.args.cooldowns.args[cooldown] then
                            specTestTimers.args.cooldowns.args[cooldown] = {
                                type = "input",
                                multiline = 5,
                                order = 2,
                                name = cooldown,
                                width = "normal",
                                set = function(_, val) ZynxRampHelperDB[specName].testTimers[cooldown] = val end,
                                get = function() return ZynxRampHelperDB[specName].testTimers[cooldown] end
                            }
                        end
                        --Add this cooldown to the options
                        if not specSpells.args[cooldown] then
                            if not ZynxRampHelperDB.options.specs[specName][cooldown] then
                                ZynxRampHelperDB.options.specs[specName][cooldown] = true
                            end
                            specSpells.args[cooldown] = {
                                type = "toggle",
                                name = cooldown,
                                order = cooldownsIndex,
                                set = function(_, val) ZynxRampHelperDB.options.specs[specName][cooldown] = val end,
                                get = function() return ZynxRampHelperDB.options.specs[specName][cooldown] end
                            }
                            cooldownsIndex = cooldownsIndex + 1
                        end
                    end
                    --Local variable to store utilities
                    local utilityOptions = {}
                    --For each utility in the data
                    for _, utility in pairs(utilities) do
                        --Check ZynxRampHelperDB if this utility exists on this boss for this difficulty on this spec
                        if not ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][utility] then
                            ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][utility] = ""
                        end
                        --Add a multiline text input with the name of that cooldown
                        utilityOptions[diffSlug .. '-' .. encounterId ..'-' .. utility] = {
                            type = "input",
                            multiline = 5,
                            name = utility,
                            desc = "Input the timings you will use this spell on, in the mm:ss format, each time in a new line",
                            width = "normal",
                            set = function(_, val) ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][utility] = val end,
                            get = function() return ZynxRampHelperDB[specName][diffSlug][tostring(encounterId)][utility] end,
                            validate = function(_, val)
                                local valid = ns:IsValidTimingsText(val)
                                if valid then
                                    return true
                                else
                                    return "Your input contains an invalid character. Your times are supposed to look like this:\n\n01:25\n00:50, p2\n@Spectral Coils #2\n\nIf your input contains parts like this:\n\n" ..
                                    "{time:00:25,SCC:468794:1}\n\nThen it is in MRT Note format, and you should import it instead."
                                end
                            end
                        }
                        --Add this utility to the test timers
                        if not specTestTimers.args.utilities.args[utility] then
                            specTestTimers.args.utilities.args[utility] = {
                                type = "input",
                                multiline = 5,
                                order = 3,
                                name = utility,
                                width = "normal",
                                set = function(_, val) ZynxRampHelperDB[specName].testTimers[utility] = val end,
                                get = function() return ZynxRampHelperDB[specName].testTimers[utility] end
                            }
                        end
                        --Add this utility to the options
                        if not specSpells.args[utility] then
                            if ZynxRampHelperDB.options.specs[specName][utility] == nil then
                                ZynxRampHelperDB.options.specs[specName][utility] = true
                            end
                            specSpells.args[utility] = {
                                type = "toggle",
                                name = utility,
                                order = utilitiesIndex,
                                set = function(_, val) ZynxRampHelperDB.options.specs[specName][utility] = val end,
                                get = function() return ZynxRampHelperDB.options.specs[specName][utility] end
                            }
                            utilitiesIndex = utilitiesIndex + 1
                        end
                    end

                    --Build string of boss' phases
                    --[[
                    local bossPhasesString = ''
                    if next(ns.bosses[encounterId].phases[diffSlug]) == nil then
                        bossPhasesString = 'This boss has no phases'
                    else
                        for i = 1, 10 do
                            if ns.bosses[encounterId].phases[diffSlug][i] then
                                local phaseTrigger = ns:FormatPhaseChangeString(ns.bosses[encounterId].phases[diffSlug][i])
                                local triggerString = phaseTrigger.count
                                if tonumber(phaseTrigger.count) == 1 then
                                    triggerString = triggerString .. 'st '
                                elseif tonumber(phaseTrigger.count) == 2 then
                                    triggerString = triggerString .. 'nd '
                                elseif tonumber(phaseTrigger.count) == 3 then
                                    triggerString = triggerString .. 'rd '
                                else
                                    triggerString = triggerString .. 'th '
                                end
                                if phaseTrigger.event == 'SCC' then
                                    triggerString = triggerString .. 'successful cast of'
                                elseif phaseTrigger.event == 'SCS' then
                                    triggerString = triggerString .. 'start of the cast of'
                                elseif phaseTrigger.event == 'SAA' then
                                    triggerString = triggerString .. 'aura application of'
                                elseif phaseTrigger.event == 'SAR' then
                                    triggerString = triggerString .. 'aura removal of'
                                end
                                local spell = C_Spell.GetSpellInfo(phaseTrigger.spell)
                                if spell then
                                    triggerString = triggerString .. ' \'' .. C_Spell.GetSpellInfo(phaseTrigger.spell).name .. '\', spell id ' .. phaseTrigger.spell
                                    bossPhasesString = bossPhasesString .. '|cffffd100Phase ' .. i .. '|r\n' .. triggerString .. '\n\n'
                                end
                            end
                        end
                    end
                    ]]--
                    --Add the spells for this fight to the appropriate difficulty in the specTable
                    specTable.args.fights.args[diffSlug].args[tostring(encounterId)] = {
                        type = "group",
                        name = encounter.name,
                        childGroups = "tab",
                        order = encounterId,
                        args = {
                            ramps = {
                                type = "group",
                                name = "Ramps",
                                order = 1,
                                args = rampTypeOptions
                            },
                            cooldowns = {
                                type = "group",
                                name = "Cooldowns",
                                order = 2,
                                args = cooldownOptions
                            },
                            utility = {
                                type = "group",
                                name = "Utility",
                                order = 3,
                                args = utilityOptions
                            },
                            abilities = {
                                type = "group",
                                name = "Boss Abilities",
                                order = 4,
                                args = {
                                    desc = {
                                        type = "description",
                                        fontSize = "medium",
                                        name = function() return ns:GetAbilityHelpText(encounterId) end
                                    }
                                }
                            }
                        }
                    }
                end
            end
            --Add spec table to the main config table
            optionsTable.args.timings.args[specName] = specTable
            --Add test timers to main config table
            optionsTable.args.testing.args[specName] = specTestTimers
            --Add spec spell list to the options
            optionsTable.args.options.args.specOptions.args[specName] = specSpells
        end

        LibStub("AceConfig-3.0"):RegisterOptionsTable("Zynx Ramp Helper", optionsTable)
        local optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Zynx Ramp Helper", "Zynx Ramp Helper")
        SLASH_ZYNXRAMPHELPER1 = "/zrh"

        SlashCmdList.ZYNXRAMPHELPER = function(msg, editBox)
            local phase = msg:match("^%s*phase%s+(%d+%.?%d*)")
            if phase then
                ns:StartPhaseManually(phase)
            else
                Settings.OpenToCategory(optionsFrame.name)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
    end
end)
