local _, ns = ...

ns.specData['RestoShaman'] = {
    spells = {},
    cooldowns = {
        [114052] = 'Ascendance',
        [108280] = 'Healing Tide Totem',
        [98008] = 'Spirit Link Totem',
        [207399] = 'Ancestral Protection Totem',
        [198838] = 'Earthen Wall Totem'
    },
    utilities = {
        [192077] = 'Wind Rush Totem',
        [108285] = 'Totemic Recall'
    },
    ramps = {
        [157153] = 'Cloudburst Totem'
    },
    rampSteps = function()
        return {
            ['Cloudburst Totem'] = {
                { text = 'Drop Cloudburst', icon = 971076, offset = 17, prerequisite = true },
                { text = 'Cloudburst Popping Soon', icon = 971076, offset = 3, countdown = true }
            }
        }
    end
}
