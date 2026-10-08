# Zynx Ramp Helper

A World of Warcraft addon that reminds healers of every step of their raid ramps. Write a plan per boss with when each ramp or cooldown should land, and the addon shows and speaks the steps leading up to it. Built for Midnight (patch 12.1, The Venomous Abyss).

## Installing

Put this folder in `World of Warcraft/_retail_/Interface/AddOns/` and name it exactly `ZynxRampHelper`, otherwise WoW won't load it.

## The window

`/zrh` (or the addon button on the minimap) opens the window, styled after EllesmereUI and using its accent colour and font when it is installed. It has three pages: Plans, Ramps and Display. `/zrh ramps` and `/zrh display` open a page directly, `/zrh stop` stops a test.

### Plans

1. On the left, pick your spec, the difficulty and the boss.
2. In the middle, pick one of the boss's abilities. Hover one for its spell tooltip, its stage and what is assigned to it. The number next to an ability is how many ramps or spells are assigned to it. Abilities your boss mod showed bars for, and ones named only in the plan, are listed below the boss's own.
3. On the right, add an assignment:
   - **Which casts**: empty for every cast, or the casts it is for like `2,4`. BigWigs and DBM number each cast of an ability on their bars, like `Spectral Coils (2)`.
   - **Ramp or spell**: type it, or pick it from the menu of your ramps and cooldowns.
   - **Sec before**: how many seconds before the ability the ramp lands (its last step) or the spell is cast.

   The line under an assignment says when its first message shows. A ramp's first message comes as far ahead of its landing as its steps say (for Evangelism, its setup step 6 global cooldowns before), a spell's countdown as long as the Spell countdown on the Display page. Hover the line for every message and its time.

Assignments are saved as ability lines in the boss's plan (`@Spectral Coils #2,4 -3 - Power Word: Barrier`). The Plan text tab shows and edits the whole plan, including times after the pull and stages, and the MRT note tab takes times from a note or copies the plan out as one.

### Testing

Every pull of a boss with BigWigs or DBM is recorded: the stages and ability bars they showed. **Replay pull** runs the longest recorded pull of the selected boss and difficulty again with your current plan, so its reminders show and speak as they would in the raid, anywhere, also while hitting a target dummy. **Test cast** on the Assignments tab pretends a cast of the selected ability is coming in a number of seconds, which works without a recorded pull.

### Ramps and Display

The Ramps page edits the ramps of each spec, see below. The Display page sets where and how big the reminders show (Show preview shows example reminders to place them), the voice, the reminder options and reading MRT notes.

## Plans

Each spec, difficulty and boss has a plan, which the Plan text tab edits. One line per timing, naming one or more ramps or spells:

```
01:25 - Evangelism
00:50 p2 - Ultimate Penitence
@Spectral Coils #2 -3 - Power Word: Barrier
02:10 - Rewind, Time Dilation
-- lines starting with -- are comments
```

| Timing | Meaning |
| --- | --- |
| `01:25` or `85` | after the pull |
| `00:50 p2` | after your boss mod shows stage 2, intermissions are stages like `p1.5` |
| `@Spectral Coils` | at every cast of a boss ability |
| `@Spectral Coils #2,4` | only the 2nd and 4th cast, the number in brackets on the boss mod bar |
| `@Spectral Coils #2 -3` | 3 seconds before the ability, `+3` is after |
| `@1299010 #2` | a spell id instead of the ability name |

A name is either a ramp from the Ramps page, or any spell by name or spell id, which gets a countdown and a reminder at its time.

- Phases follow the stages BigWigs or DBM detect. Without a boss mod, start a phase with `/zrh phase 2` from a macro. When a boss returns to a stage, its reminders run again.
- Ability lines follow the bars BigWigs or DBM show. A ramp is timed so its last step lands with the ability, and moves when the boss mod corrects the bar. Steps that should have started before the bar appeared show as soon as it does. The Plans page lists the abilities your boss mod showed on each boss. With both boss mods installed, the first one to show a matching bar is followed for that pull.
- An MRT note can be pasted on the MRT note tab to take your times from it, and a plan can be copied out as note lines. With the MRT options on the Display page, the times are read from your active notes at the pull instead. Ability lines stay in the plan either way.
- When a pull starts on a raid boss that isn't in [Config/Bosses.lua](Config/Bosses.lua), its encounter id is printed in chat.

## Ramps

The Ramps page has the ramps of each spec. They start from a few starter ramps and can be changed, added or deleted. The starter ramps follow the Midnight 12.1 healing guides: Evangelism and Ultimate Penitence for Discipline, Stasis for Preservation, Tranquility and Tree of Life for Restoration Druid, and Spirit Link Totem for Restoration Shaman. Holy Priest and Holy Paladin don't ramp, their cooldowns go in the plan as spells. A ramp has the spell MRT notes use for it and one step per line:

```
charges 194509 | Save Radiance charges | setup
6gcd | Start ramp: Pain, Shield, Flash Heal | setup | icon 17 | say Start ramp
3gcd | Evangelism
2gcd | Radiance twice | icon 194509
0 | Mind Blast, Penance | icon 47540 | say Penance
```

| Part | Meaning |
| --- | --- |
| `20` | 20 seconds before the ramp lands |
| `12gcd` | 12 global cooldowns before it, shortened by haste |
| `charges <spell>` | once that spell's charges need all the time left to come back |
| `setup` | a setup step, the only steps shown with Only Setup Steps on |
| `countdown` | counts down on the icon |
| `icon <spell>` | the icon to show, by spell id or name |
| `say <text>` | what text to speech says instead of the text |

Without an icon option, a step shows the icon of the spell in its text, or else the ramp's spell.

## Midnight notes

Addons can't read the combat log any more, and spell charges and haste can be secret during encounters. When charges can't be read, charges steps assume both charges are spent and show early. Haste and recharge times use the last values read outside the encounter.

## Code

| Folder | Contents |
| --- | --- |
| [Config](Config/) | `Bosses.lua` raid bosses and difficulties, `Specs.lua` the healer specs, their starter ramps and cooldowns, `Abilities.lua` each boss's abilities, from BigWigs |
| [Core](Core/) | `Database.lua` saved settings, `Ramps.lua` the ramp format and reminder steps, `PlanText.lua` the plan format and MRT notes, `Plan.lua` building a fight's reminders, `Fight.lua` the fight timer and phases, `BossMods.lua` BigWigs and DBM stages and bars, `Test.lua` recording pulls and tests, `Spec.lua` the player's spec and haste, `Util.lua` small helpers |
| [UI](UI/) | `Display.lua` the on-screen reminders, styled like the window, and text to speech, `Theme.lua` the EllesmereUI style colours and widgets, `Window.lua` the window and `/zrh`, `Planner.lua` the Plans page, `RampsPage.lua` and `DisplayPage.lua` the other pages |
| `main.lua` | Starts and stops the fight on encounter events |
