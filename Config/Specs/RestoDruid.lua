local _, ns = ...

ns.specData['RestoDruid'] = {
    spells = {},
    cooldowns = {
        [740] = 'Tranquility'
    },
    utilities = {
        [77761] = 'Stampeding Roar',
        [102793] = 'Ursol\'s Vortex',
        [102342] = 'Ironbark'
    },
    ramps = {
        [197721] = 'Flourish'
    },
    rampSteps = function()
        return {
            ['Flourish'] = {
                { text = 'Start Ramping', icon = 136081, offset = 15, prerequisite = true },
                { text = 'Flourish Soon', icon = 538743, offset = 3, countdown = true },
                { text = 'Flourish', icon = 538743, offset = 0 }
            }
        }
    end
}
