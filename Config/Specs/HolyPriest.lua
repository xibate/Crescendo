local _, ns = ...

ns.specData['HolyPriest'] = {
    spells = {},
    cooldowns = {
        [64843] = 'Divine Hymn',
        [200183] = 'Apotheosis',
        [120517] = 'Halo',
        [372835] = 'Lightwell'
    },
    utilities = {
        [64901] = 'Symbol of Hope',
        [73325] = 'Leap of Faith',
        [47788] = 'Guardian Spirit',
        [32375] = 'Mass Dispell' --Misspelled, but saved timings are stored under this name
    },
    ramps = {},
    rampSteps = function()
        return {}
    end
}
