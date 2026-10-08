local _, ns = ...

local GCD, RADIANCE = 61304, 194509

ns.specData['Discipline'] = {
    spells = {
        [GCD] = { name = 'GCD', cd = 1.5, haste = true },
        [RADIANCE] = { name = 'Power Word: Radiance', cd = 18, charges = true, talents = { [390684] = -3 } }
    },
    cooldowns = {
        [62618] = 'Barrier'
    },
    utilities = {
        [33206] = 'Pain Suppression',
        [73325] = 'Leap of Faith',
        [32375] = 'Mass Dispel'
    },
    ramps = {
        [472433] = 'Evangelism',
        [421453] = 'Ultimate Penitence',
        [RADIANCE] = 'Double Radiance'
    },
    rampSteps = function(cd)
        return {
            ['Evangelism'] = {
                { text = 'Save Radiance', icon = 1386546, chargesOf = RADIANCE, offset = cd(GCD), prerequisite = true },
                { text = 'Ramp for Evang', tts = 'Ramp for Evangelism', icon = 135940, offset = 11 * cd(GCD), prerequisite = true },
                { text = 'Double Radiance', icon = 1386546, offset = 2 * cd(GCD) },
                { text = 'Evangelism', icon = 135895, offset = 0 }
            },
            ['Ultimate Penitence'] = {
                { text = 'Ramp for UP', tts = 'Ramp for Ultimate Penitence', icon = 1060982, offset = 6 * cd(GCD), prerequisite = true },
                { text = 'Save one Radiance', icon = 1386546, offset = cd(RADIANCE), prerequisite = true },
                { text = 'UP Soon', tts = 'uppies soon', icon = 253400, offset = 3, countdown = true },
                { text = 'Ultimate Penitence', icon = 253400, offset = 0 }
            },
            ['Double Radiance'] = {
                { text = 'Save Radiances', icon = 1386546, chargesOf = RADIANCE, offset = cd(GCD), prerequisite = true },
                { text = 'Ramp for Double Radiance', icon = 135940, offset = 11 * cd(GCD), prerequisite = true },
                { text = 'Double Radiance', icon = 1386546, offset = 2 * cd(GCD) },
                { text = 'Heal Now', icon = 136224, offset = 0 }
            }
        }
    end
}
