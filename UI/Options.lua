local _, ns = ...

local VERSION = "2.0.0"

local PLAN_HELP = "One line per timing, naming one or more ramps or spells:\n\n" ..
    "|cffffd10001:25 - Evangelism|r  1:25 after the pull\n" ..
    "|cffffd10000:50 p2 - Ultimate Penitence|r  50 seconds after your boss mod shows stage 2 (intermissions are p1.5)\n" ..
    "|cffffd100@Spectral Coils #2 -3 - Barrier|r  3 seconds before the 2nd Spectral Coils on your boss mod's bar\n" ..
    "|cffffd10002:10 - Rewind, Time Dilation|r  several at once\n\n" ..
    "Ramps come from the Ramps tab, any other spell gets a countdown and a reminder at its time. For ability lines, '#2,4' picks " ..
    "casts by the number on the bar, '-3' or '+3' moves the timing, and a spell id works instead of the name. Without a boss mod, " ..
    "start a phase with /zrh phase 2. Lines starting with -- are comments."

local RAMP_HELP = "One step per line: |cffffd100when | text | options|r\n\n" ..
    "|cffffd100when|r  seconds before the ramp lands (20), global cooldowns before it (12gcd), or 'charges <spell>' to show " ..
    "the step once that spell's charges need all the time left to come back\n" ..
    "|cffffd100options|r  setup (a setup step), countdown (counts down on the icon), icon <spell>, say <text to speak>\n\n" ..
    "A step shows the icon of the spell in its text when there is one, otherwise the ramp's spell. The spell id is what MRT notes use for this ramp."

local ABOUT = "Zynx Ramp Helper reminds healers of every step of their raid ramps. Write a plan per boss with when each ramp " ..
    "or cooldown should land, and the addon shows and speaks the steps leading up to it.\n\n" ..
    "Plan: the timings for each boss and difficulty, by time, by boss mod stage or by boss ability.\n" ..
    "Ramps: the steps of each ramp of your spec, change them or add your own.\n" ..
    "Display: size, position and voice of the reminders, and reading times from MRT notes.\n" ..
    "Testing: a plan that runs when you start combat on a target dummy.\n\n" ..
    "Version " .. VERSION

local function UI()
    return ns.db.ui
end

local function SelectedSpec()
    local ui = UI()
    if not ns.specNames[ui.spec or ''] then
        ui.spec = ns:GetPlayerSpecKey() or 'Discipline'
    end
    return ui.spec
end

local function SelectedDifficulty()
    local ui = UI()
    if not ns.difficulties[ui.difficulty or 0] then
        ui.difficulty = 16
    end
    return ui.difficulty, ns.difficulties[ui.difficulty].slug
end

local function SelectedBoss()
    local ui = UI()
    if not ns.bosses[ui.boss or 0] then
        local first
        for encounterId in pairs(ns.bosses) do
            if not first or encounterId < first then
                first = encounterId
            end
        end
        ui.boss = first
    end
    return ui.boss
end

local function SelectedRamp()
    local ui = UI()
    local ramps = ns:GetRamps(SelectedSpec())
    if not ramps[ui.ramp or ''] then
        ui.ramp = ns:GetRampNames(SelectedSpec())[1]
    end
    return ui.ramp, ui.ramp and ramps[ui.ramp]
end

local function Names(source, field)
    return function()
        local values = {}
        for id, entry in pairs(source) do
            values[id] = field and entry[field] or entry
        end
        return values
    end
end

local function SpecSelect(order)
    return {
        type = "select",
        name = "Spec",
        order = order,
        values = Names(ns.specNames),
        get = SelectedSpec,
        set = function(_, specKey) UI().spec = specKey end
    }
end

local function Header(name, order)
    return { type = "header", name = name, order = order }
end

local function Text(text, order)
    return { type = "description", name = text, order = order, fontSize = "medium" }
end

local function PlanTab()
    return {
        type = "group",
        name = "Plan",
        order = 1,
        args = {
            spec = SpecSelect(1),
            difficulty = {
                type = "select",
                name = "Difficulty",
                order = 2,
                values = Names(ns.difficulties, 'name'),
                get = function() return (SelectedDifficulty()) end,
                set = function(_, diffId) UI().difficulty = diffId end
            },
            boss = {
                type = "select",
                name = "Boss",
                order = 3,
                values = Names(ns.bosses, 'name'),
                get = SelectedBoss,
                set = function(_, encounterId) UI().boss = encounterId end
            },
            plan = {
                type = "input",
                name = "Plan",
                order = 4,
                multiline = 16,
                width = "full",
                get = function()
                    local _, diffSlug = SelectedDifficulty()
                    return ns:GetPlan(SelectedSpec(), diffSlug, SelectedBoss())
                end,
                set = function(_, text)
                    local _, diffSlug = SelectedDifficulty()
                    ns:SetPlan(SelectedSpec(), diffSlug, SelectedBoss(), text)
                end,
                validate = function(_, text) return ns:CheckPlan(text) end
            },
            help = Text(PLAN_HELP, 5),
            seenHeader = Header("Abilities seen on this boss", 10),
            seen = Text(function() return ns:GetSeenAbilitiesText(SelectedBoss()) end, 11),
            noteHeader = Header("MRT note", 20),
            noteHelp = Text("Paste an MRT note to take your times from it, or copy this plan out as note lines. Boss ability lines stay in the plan.", 21),
            note = {
                type = "input",
                name = "Note",
                order = 22,
                multiline = 8,
                width = "full",
                get = function() return UI().note end,
                set = function(_, text) UI().note = text end
            },
            import = {
                type = "execute",
                name = "Use Times From Note",
                order = 23,
                width = 1.2,
                confirm = true,
                confirmText = "Replace the times in this plan with your lines from the note?",
                func = function()
                    local _, diffSlug = SelectedDifficulty()
                    ns:ImportNoteIntoPlan(SelectedSpec(), diffSlug, SelectedBoss(), UI().note or '')
                end
            },
            export = {
                type = "execute",
                name = "Copy Plan As Note",
                order = 24,
                width = 1.2,
                func = function()
                    local _, diffSlug = SelectedDifficulty()
                    UI().note = ns:PlanToNote(ns:GetPlan(SelectedSpec(), diffSlug, SelectedBoss()), SelectedSpec())
                end
            }
        }
    }
end

local function RampsTab()
    return {
        type = "group",
        name = "Ramps",
        order = 2,
        args = {
            spec = SpecSelect(1),
            ramp = {
                type = "select",
                name = "Ramp",
                order = 2,
                values = function()
                    local values = {}
                    for _, name in ipairs(ns:GetRampNames(SelectedSpec())) do
                        values[name] = name
                    end
                    return values
                end,
                get = function() return (SelectedRamp()) end,
                set = function(_, name) UI().ramp = name end
            },
            spellId = {
                type = "input",
                name = "Spell ID",
                desc = "The spell MRT notes use for this ramp",
                order = 3,
                disabled = function() return not select(2, SelectedRamp()) end,
                get = function()
                    local _, ramp = SelectedRamp()
                    return ramp and ramp.spellId and tostring(ramp.spellId) or ''
                end,
                set = function(_, text)
                    local _, ramp = SelectedRamp()
                    ramp.spellId = tonumber(text)
                end,
                validate = function(_, text)
                    return (text == '' or tonumber(text) ~= nil) or "The spell id is a number"
                end
            },
            steps = {
                type = "input",
                name = "Steps",
                order = 4,
                multiline = 10,
                width = "full",
                disabled = function() return not select(2, SelectedRamp()) end,
                get = function()
                    local _, ramp = SelectedRamp()
                    return ramp and ramp.steps or ''
                end,
                set = function(_, text)
                    local _, ramp = SelectedRamp()
                    ramp.steps = text
                end,
                validate = function(_, text)
                    local steps, problem = ns:ParseRampSteps(text)
                    return steps ~= nil or problem
                end
            },
            help = Text(RAMP_HELP, 5),
            manageHeader = Header("Add or remove ramps", 10),
            newName = {
                type = "input",
                name = "New ramp name",
                order = 11,
                get = function() return UI().newRamp end,
                set = function(_, text) UI().newRamp = text end
            },
            add = {
                type = "execute",
                name = "Add Ramp",
                order = 12,
                func = function()
                    local name = (UI().newRamp or ''):match('^%s*(.-)%s*$')
                    if name ~= '' and not ns:FindRamp(SelectedSpec(), name) then
                        ns:GetRamps(SelectedSpec())[name] = { steps = "3 | " .. name .. " soon | countdown\n0 | " .. name }
                        UI().ramp = name
                        UI().newRamp = nil
                    end
                end
            },
            delete = {
                type = "execute",
                name = "Delete Ramp",
                order = 13,
                confirm = true,
                confirmText = "Delete this ramp?",
                disabled = function() return not select(2, SelectedRamp()) end,
                func = function()
                    ns:GetRamps(SelectedSpec())[(SelectedRamp())] = nil
                    UI().ramp = nil
                end
            },
            restore = {
                type = "execute",
                name = "Restore Starter Ramps",
                desc = "Adds the ramps the addon comes with for this spec back, replacing ramps with the same name",
                order = 14,
                confirm = true,
                confirmText = "Put the starter ramps of this spec back? Changes to them are lost.",
                func = function() ns:RestoreStarterRamps(SelectedSpec()) end
            }
        }
    }
end

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

local function DisplayTab()
    return {
        type = "group",
        name = "Display",
        order = 3,
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
            positionHeader = Header("Position", 10),
            framePositionX = Option({ type = "range", name = "Display X Position", softMin = -1000, softMax = 1000, order = 11, step = 1, bigStep = 10 }, 'framePositionX', true),
            framePositionY = Option({ type = "range", name = "Display Y Position", softMin = -1000, softMax = 1000, order = 12, step = 1, bigStep = 10 }, 'framePositionY', true),
            growDirection = Option({ type = "select", name = "Grow Direction", order = 13, values = { top = 'top', bottom = 'bottom', left = 'left', right = 'right' } }, 'growDirection', true),
            sizeHeader = Header("Size", 20),
            textSize = Option({ type = "range", name = "Main Text Size", min = 0.5, max = 5, order = 21, step = 0.1, bigStep = 0.1 }, 'textSize', true),
            timerSize = Option({ type = "range", name = "Timer Text Size", min = 0.5, max = 5, order = 22, step = 0.1, bigStep = 0.1 }, 'timerSize', true),
            iconSizeW = Option({ type = "range", name = "Icon Width", min = 10, max = 200, order = 23, step = 1, bigStep = 2 }, 'iconSizeW', true),
            iconSizeH = Option({ type = "range", name = "Icon Height", min = 10, max = 200, order = 24, step = 1, bigStep = 2 }, 'iconSizeH', true),
            displaySpacing = Option({ type = "range", name = "Display Spacing", min = 0, softMin = 40, max = 500, softMax = 300, order = 25, step = 1, bigStep = 5 }, 'displaySpacing', true),
            ttsHeader = Header("Text to Speech", 30),
            ttsPlay = {
                type = "execute",
                name = "Play Voice",
                desc = "Plays a message to test the voice. This won't work if text to speech is off",
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
            remindersHeader = Header("Reminders", 40),
            preReqsOnly = Option({
                type = "toggle",
                name = "Only Setup Steps",
                desc = "Leave out the final press of each ramp and only show the steps marked as setup, for when another addon or weakaura already warns you about the press.",
                order = 41
            }, 'preReqsOnly'),
            timerDuration = Option({
                type = "range",
                name = "Spell Countdown",
                desc = "How many seconds before a spell in the plan its countdown starts",
                min = 2,
                max = 10,
                order = 42,
                step = 1
            }, 'timerDuration'),
            mrtHeader = Header("MRT Notes", 50),
            mrtDescription = Text("With one of these on, the times of your plans are replaced by your lines in the selected MRT notes. " ..
                "Boss ability lines in your plans still apply.", 51),
            readFromNote = Option({ type = "toggle", name = "Use Main MRT Note", order = 52 }, 'readFromNote'),
            mrtPersonalNote = Option({ type = "toggle", name = "Use Personal MRT Note", order = 53 }, 'mrtPersonalNote')
        }
    }
end

local function TestingTab()
    return {
        type = "group",
        name = "Testing",
        order = 4,
        args = {
            help = Text("With testing mode on, starting combat with anything runs the test plan of your current spec, so you can try your reminders on a target dummy.", 1),
            testMode = {
                type = "toggle",
                name = "Testing Mode",
                order = 2,
                get = function() return ns.db.testing.testMode end,
                set = function(_, enabled) ns.db.testing.testMode = enabled end
            },
            spec = SpecSelect(3),
            plan = {
                type = "input",
                name = "Test Plan",
                order = 4,
                multiline = 10,
                width = "full",
                get = function() return ns:GetTestPlan(SelectedSpec()) end,
                set = function(_, text) ns:SetTestPlan(SelectedSpec(), text) end,
                validate = function(_, text) return ns:CheckPlan(text) end
            }
        }
    }
end

local function BuildOptionsTable()
    return {
        type = "group",
        childGroups = "tab",
        args = {
            plan = PlanTab(),
            ramps = RampsTab(),
            display = DisplayTab(),
            testing = TestingTab(),
            about = { type = "group", name = "About", order = 5, args = { text = Text(ABOUT, 1) } }
        }
    }
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
