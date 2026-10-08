local _, ns = ...

local ENGULF, TEMPORAL_ANOMALY = 443328, 373861

ns.specData['Preservation'] = {
    spells = {
        [ENGULF] = { name = 'Engulf', cd = 27, haste = true, charges = true },
        [TEMPORAL_ANOMALY] = { name = 'Temporal Anomaly', cd = 15, haste = true }
    },
    cooldowns = {
        [370564] = 'Stasis Release',
        [359816] = 'Dreamflight',
        [363534] = 'Rewind',
        [ENGULF] = 'Engulf'
    },
    utilities = {
        [357170] = 'Time Dilation',
        [374968] = 'Time Spiral',
        [374227] = 'Zephyr',
        [370665] = 'Rescue',
        [406735] = 'Spatial Paradox',
        [363916] = 'Obsidian Scales',
        [374348] = 'Renewing Blaze'
    },
    ramps = {
        [370537] = 'Stasis',
        [370960] = 'EC',
        [370984] = 'EC', --Some cooldown planners use this id for Emerald Communion, so notes made with them still import
        [443330] = 'Double Engulf'
    },
    rampSteps = function(cd)
        return {
            ['Stasis'] = {
                { text = 'Save Engulfs', icon = 5927629, chargesOf = ENGULF, offset = 0, prerequisite = true },
                { text = 'Save TA', tts = 'Save tea a', icon = 4630480, offset = 15 + cd(TEMPORAL_ANOMALY), prerequisite = true },
                { text = 'Save DB', icon = 4622454, offset = 30, prerequisite = true },
                { text = 'Ramp for Stasis', icon = 4630480, offset = 18, prerequisite = true },
                { text = 'Stasis Soon', icon = 4630476, offset = 3, countdown = true },
                { text = 'Stasis', icon = 4630476, offset = 0 }
            },
            ['EC'] = {
                { text = 'Save TA', tts = 'Save tea a', icon = 4630480, offset = 18 + cd(TEMPORAL_ANOMALY), prerequisite = true },
                { text = 'Ramp for EC', icon = 4630480, offset = 18, prerequisite = true },
                { text = 'EC Soon', icon = 4630447, offset = 3, countdown = true },
                { text = 'EC', icon = 4630447, offset = 0 }
            },
            ['Double Engulf'] = {
                { text = 'Save Engulfs', icon = 5927629, chargesOf = ENGULF, offset = 0, prerequisite = true },
                { text = 'Save TA', tts = 'Save tea a', icon = 4630480, offset = 15 + cd(TEMPORAL_ANOMALY), prerequisite = true },
                { text = 'Save DB', icon = 4622454, offset = 30, prerequisite = true },
                { text = 'Ramp for Double Engulf', icon = 4630480, offset = 18, prerequisite = true },
                { text = 'Double Engulf Soon', icon = 4914680, offset = 3, countdown = true },
                { text = 'Double Engulf', icon = 4914680, offset = 0 }
            }
        }
    end
}
