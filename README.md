# Crescendo

A World of Warcraft addon that reminds healers of every step of their raid ramps. Write a plan per boss with when each ramp or cooldown should land, and the addon shows and speaks the steps leading up to it. Built for Midnight: The Venomous Abyss, The Unbinding of Kith'ix and the Midnight lair boss Nymrissa Wavecaller, plus the season 1 raids (The Voidspire, The Dreamrift, March on Quel'Danas).

## Installing

Put this folder in `World of Warcraft/_retail_/Interface/AddOns/` and name it exactly `Crescendo`, otherwise WoW won't load it.

Coming from Zynx Ramp Helper, the addon's old name: delete the old `ZynxRampHelper` folder, and to keep your plans and ramps rename `WTF/Account/<account>/SavedVariables/ZynxRampHelper.lua` to `Crescendo.lua` while the game is closed. Crescendo moves them over at the next login.

## The window

`/cres` (or `/crescendo`, or the addon button on the minimap) opens the window, styled after EllesmereUI and using its accent colour and font when it is installed. It has three pages: Plans, Ramps and Display. `/cres ramps` and `/cres display` open a page directly, `/cres stop` stops a test.

### Plans

1. On the left, pick your spec, the difficulty and the boss. Bosses are listed under their raid; click a raid's name to fold it away (the season 1 raids start folded).
2. In the middle, pick one of the boss's abilities. For bosses with stages, choose how they are listed:
   - **By stage**: each stage with the abilities that happen in it. An ability that comes back in a later stage, like Spectral Coils in Ula'tek's intermission, is listed under every stage it happens in. What you assign there only triggers in that stage.
   - **All stages**: every ability once. What you assign there triggers in every stage.

   Click a stage's or group's name to fold it away. On Heroic, abilities that are only on Mythic are left out. Hover an ability for its spell tooltip, the stages it happens in and what is assigned to it. The number next to it is how many assignments trigger there. Abilities without a stage, and ones your boss mod showed bars for or only named in the plan, are listed under Any stage.
3. On the right, click **+ Add assignment** and pick what to cast: one of your ramps, cooldowns or equipped on-use trinkets, or type any spell or item. Each assignment reads like a sentence: *what* lands *3* sec before *every cast*.
   - Use **-** and **+** (or type a number) for how many seconds before the ability the ramp lands (its last step) or the spell is cast.
   - Pick which casts, shown by their numbers: all casts, odd casts (1, 3, 5...), even casts (2, 4, 6...), every 3rd from the 1st, 2nd or 3rd, only the 1st, or **Pick casts...** to list casts like `2,4` or write a pattern like `every 4 from 2`. BigWigs and DBM number each cast of an ability on their bars, like `Spectral Coils (2)`.

   The line under an assignment says when its first message shows. A ramp's first message comes as far ahead of its landing as its steps say (for Evangelism, its setup step 6 global cooldowns before), a spell's countdown as long as the Spell countdown on the Display page. Hover the line for every message and its time.

Assignments are saved as ability lines in the boss's plan (`@Spectral Coils p2.5 #2,4 -3 - Power Word: Barrier`, where `p2.5` is the stage). The Plan text tab shows and edits the whole plan, including times after the pull and stages, and the MRT note tab takes times from a note or copies the plan out as one.

### Testing

Every pull of a boss with BigWigs or DBM is recorded: the stages and ability bars they showed. The **Timeline** tab shows the longest recorded pull of the selected boss and difficulty at once: when each stage started, when each ability went off and when your reminders would show with your current plan. Click an ability there to assign something to it. **Play** on a line, or **Replay pull**, runs the pull again from there with your plan, so its reminders show and speak as they would in the raid, anywhere, also while hitting a target dummy, and the timeline follows along. **Test cast** on the Assignments tab pretends a cast of the selected ability is coming in a number of seconds, which works without a recorded pull.

### Ramps and Display

The Ramps page edits the ramps of each spec, see below. The Display page sets where and how big the reminders show, and whether plans are saved for all characters or for this character only (it starts with a copy of the plans for all characters). **Unlock** (or `/cres unlock`) works like EllesmereUI's unlock mode: the screen dims under a grid and the reminders show with a box to drag them, and a toolbar has the exact position, nudge buttons, snap to grid and Lock. Escape or entering combat locks them too. The page also sets the voice, the reminder options and reading MRT notes.

**Hide reminders while the spell or trinket is on cooldown** leaves out the reminders of a ramp, spell or trinket that won't be ready by the time it should land. A ramp goes by the spell set for it on the Ramps page. During boss fights the game can hide cooldowns from addons; then the addon goes by your last cast of the spell and the cooldown it saw when it could read it, and when it can't tell, the reminder shows.

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
| `@Spectral Coils #every 2` | every other cast, `#every 3 from 2` is the 2nd, 5th, 8th... |
| `@Spectral Coils p2.5` | only casts in stage 2.5 (the intermission), `p1,3` is stages 1 and 3 |
| `@Spectral Coils #2 -3` | 3 seconds before the ability, `+3` is after |
| `@1299010 #2` | a spell id instead of the ability name |

A name is a ramp from the Ramps page, any spell by name or spell id, or a trinket, which get a countdown and a reminder at their time. A trinket is named by its item name when it is equipped, `Trinket 1` or `Trinket 2` for whatever is in the top or bottom trinket slot at the pull, or `item:<id>`. MRT notes name trinkets by the spell of their use effect, which works both ways for equipped trinkets.

- Phases follow the stages BigWigs or DBM detect. Without a boss mod, start a phase with `/cres phase 2` from a macro. When a boss returns to a stage, its reminders run again.
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
| [Config](Config/) | `Bosses.lua` raids, bosses and difficulties (generated from BigWigs), `Specs.lua` the healer specs, their starter ramps and cooldowns, `Abilities.lua` each boss's abilities and stages, from BigWigs |
| [Core](Core/) | `Database.lua` saved settings, `Ramps.lua` the ramp format and reminder steps, `Trinkets.lua` trinkets in plans, `PlanText.lua` the plan format and MRT notes, `Plan.lua` building a fight's reminders, `Fight.lua` the fight timer and phases, `Cooldowns.lua` whether a spell or trinket is ready, `BossMods.lua` BigWigs and DBM stages and bars, `Test.lua` recording pulls and tests, `Timeline.lua` what happens in a recorded pull, `Spec.lua` the player's spec and haste, `Util.lua` small helpers |
| [UI](UI/) | `Display.lua` the on-screen reminders, styled like the window, and text to speech, `Theme.lua` the EllesmereUI style colours and widgets, `Window.lua` the window and `/cres`, `Planner.lua` the Plans page, `RampsPage.lua` and `DisplayPage.lua` the other pages, `Unlock.lua` moving the reminders |
| `main.lua` | Starts and stops the fight on encounter events |
| [tools](tools/) | `gen_bosses.py` regenerates `Config/Bosses.lua` and `Config/Abilities.lua` from a BigWigs checkout, not part of the addon |
